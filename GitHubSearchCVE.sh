#!/bin/bash
set -euo pipefail

# Check if ctrl + c was clicked to finish the script closing the opened PIDs
trap ctrl_c INT

# Colors
green="\e[0;32m\033[1m"
red="\e[0;31m\033[1m"
gray="\e[0;37m\033[0m"
yellow="\e[0;33m\033[1m"
endColour="\033[0m\e[0m"
purple="\e[0;35m\033[1m"

# Common variables
downloadTarget="/tmp/CVEDownloaded"         # The output directory, where the exploits have been downloaded
counter=1                                   # Useful counter to control the number of exploits to download
maxResults=10                               # Default max results to fetch (controllable via -n)
portToDeploy=8080                           # First port to deploy the HTTP server (range: 8080-8089)
pidToDelete=""                              # Stores PIDs of HTTP servers launched, for cleanup
curlA=()                                    # Array to store repo metadata objects from GitHub API
exportRepo=""                               # Variable to obtain only the URL of the GitHub repository
repoSource=""                               # GitHub repository path (user/repository)
userSource=""                               # User that owns the repository
networkC=""                                 # All available network cards (one per line)
networkCard=()                              # All available network cards (indexed array)
myIPAddress=""                              # All available IP addresses (one per line)
myIP=()                                     # All available IP addresses (indexed array)
exploitCVE=""                               # CVE identifier provided by user
exploitLang=""                              # Language filter provided by user
exploitMode=""                              # Mode: Download, SCP, or HTTP
exploitUser=""                              # Target user for SCP mode
exploitTarget=""                            # Target host for SCP mode
exploitNoDep=""                             # Dependency check flag
GITHUB_TOKEN="${GITHUB_TOKEN:-}"            # Optional GitHub token (set in env to avoid rate limiting)
LOGFILE=""                                  # Log file path, set during preparation()

# ─────────────────────────────────────────────
# Logging helper
# ─────────────────────────────────────────────
function log(){
    local level="$1"; shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" >> "$LOGFILE"
}

# ─────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────
function helpView(){
    echo -e "${yellow}[*]${endColour}${gray} How to use:${endColour} ${purple}GitHubSearchCVE -e [CVE-XXX-XXXX] -l [Python] -m [Download|SCP|HTTP] -u [user] -t [10.10.10.25]${endColour}"
    echo -e "    ${purple}-e${endColour}${gray}: CVE to find. Format: CVE-YEAR-CODE  (e.g. CVE-2021-3156)${endColour}"
    echo -e "    ${purple}-l${endColour}${gray}: Language filter. Examples: Python, Shell, C, C#, Java, JavaScript, PHP, Go, Ruby, PowerShell${endColour}"
    echo -e "    ${purple}-m${endColour}${gray}: Mode — 'Download' saves to /tmp/CVEDownloaded, 'SCP' sends to target (-t), 'HTTP' serves locally${endColour}"
    echo -e "    ${purple}-n${endColour}${gray}: Max number of results to fetch (default: 10, max: 10)${endColour}"
    echo -e "    ${purple}-u${endColour}${gray}: User for SCP mode.${endColour}"
    echo -e "    ${purple}-t${endColour}${gray}: Target host for SCP mode.${endColour}"
    echo -e "    ${purple}-z${endColour}${gray}: Dependency check — use '-z on' to check and install dependencies.${endColour}"
    echo -e "    ${purple}-h${endColour}${gray}: Help. Show this message.${endColour}"
    echo ""
    echo -e "    ${gray}Tip: set GITHUB_TOKEN env var to avoid API rate limiting (10 req/min → 5000 req/min).${endColour}"
    exit 0
}

# ─────────────────────────────────────────────
# Dependency check (only needs root for apt-get)
# ─────────────────────────────────────────────
function depsCheck(){
    if [[ -f /usr/bin/apt-get ]]; then
        clear
        echo "[i] Running on Debian-based Linux"
        local dependencies=(git curl jq netcat-openbsd python3)
        echo -e "${yellow}[*]${endColour}${gray} Checking for dependencies...${endColour}"
        sleep 1s
        for dep in "${dependencies[@]}"; do
            echo -ne "${yellow}[*]${endColour}${purple} $dep${endColour}..."
            sleep 0.5s
            # FIX 1: was using undefined $program — now correctly uses $dep
            if command -v "$dep" &>/dev/null; then
                echo -e "${green}(V)${endColour}"
                log "INFO" "Dependency OK: $dep"
            else
                echo -e "${red}(X)${endColour}"
                echo -e "${yellow}[+]${endColour} Installing: ${purple}$dep${endColour}..."
                apt-get install "$dep" -y > /dev/null 2>&1
                log "INFO" "Installed dependency: $dep"
            fi
            sleep 0.5s
        done
    else
        local missing=()
        for bin in git curl jq python3; do
            command -v "$bin" &>/dev/null || missing+=("$bin")
        done
        echo -e "${yellow}[i]${endColour} Not running on a Debian-based Linux."
        if [[ ${#missing[@]} -gt 0 ]]; then
            echo -e "${red}[X]${endColour} Missing dependencies: ${missing[*]}"
            echo -e "${yellow}[i]${endColour} Please install them manually and re-run."
            log "ERROR" "Missing dependencies on non-Debian system: ${missing[*]}"
            exit 1
        else
            echo -e "${yellow}[i]${endColour} All dependencies found — you can continue."
            log "INFO" "All dependencies present on non-Debian system."
        fi
    fi
}

# ─────────────────────────────────────────────
# Prepare output directory and log file
# ─────────────────────────────────────────────
function preparation(){
    if [ -d "$downloadTarget" ]; then
        rm -rf "${downloadTarget:?}"/*
    else
        mkdir -p "$downloadTarget"
    fi

    LOGFILE="${downloadTarget}/session_$(date +%Y%m%d_%H%M%S).log"
    touch "$LOGFILE"
    log "INFO" "Session started. CVE=$exploitCVE Lang=$exploitLang Mode=$exploitMode"
    echo -e "${gray}[i] Log file: ${LOGFILE}${endColour}"
}

# ─────────────────────────────────────────────
# Validate CVE format
# ─────────────────────────────────────────────
function checkCVE(){
    # FIX 4: normalise to uppercase before any use
    exploitCVE=$(echo "$exploitCVE" | tr '[:lower:]' '[:upper:]')
    if [[ $exploitCVE =~ ^CVE-[1-2][09][0-9]{2}-[0-9]{1,7}$ ]]; then
        log "INFO" "CVE format validated: $exploitCVE"
    else
        echo -e "${red}[X]${endColour} Invalid CVE format. Expected: CVE-YEAR-CODE (e.g. CVE-2021-3156)"
        log "ERROR" "Invalid CVE format provided: $exploitCVE"
        exit 1
    fi
}

# ─────────────────────────────────────────────
# Search GitHub for CVE repositories
# ─────────────────────────────────────────────
function searchCVE(){
    # Build auth header if token is available (avoids 10 req/min rate limit)
    local auth_header=()
    if [[ -n "$GITHUB_TOKEN" ]]; then
        auth_header=(-H "Authorization: token ${GITHUB_TOKEN}")
        echo -e "${green}[+]${endColour} Using GitHub token for authenticated requests."
        log "INFO" "GitHub token present — using authenticated API requests."
    else
        echo -e "${yellow}[!]${endColour} No GITHUB_TOKEN set. Limited to 10 API requests/min."
        log "WARN" "No GitHub token — unauthenticated API (10 req/min limit)."
    fi

    echo -e "${yellow}[*]${endColour} Searching GitHub for ${purple}${exploitCVE}${endColour} (lang: ${exploitLang}, max: ${maxResults})..."

    # FIX 6: use per_page to request exactly as many results as needed; also sort by stars
    local api_url="https://api.github.com/search/repositories?q=${exploitCVE}&sort=stars&order=desc&per_page=${maxResults}"

    local raw_json
    raw_json=$(curl -s \
        "${auth_header[@]}" \
        -H "Accept: application/vnd.github.v3+json" \
        "$api_url")

    # Check for API errors
    if echo "$raw_json" | jq -e '.message' &>/dev/null; then
        local api_msg
        api_msg=$(echo "$raw_json" | jq -r '.message')
        echo -e "${red}[X]${endColour} GitHub API error: $api_msg"
        log "ERROR" "GitHub API returned error: $api_msg"
        exit 1
    fi

    # FIX 7: extract rich metadata — stars, last push, language, URL, description
    # Store as a JSON array of objects for use in the interactive selector
    curlA=()
    while IFS= read -r line; do
        curlA+=("$line")
    done < <(echo "$raw_json" | jq -c --arg lang "$exploitLang" '
        .items[]
        | select(
            .language != null
            and (.language | ascii_downcase) == ($lang | ascii_downcase)
          )
        | {
            stars:       .stargazers_count,
            pushed:      .pushed_at,
            language:    .language,
            clone_url:   .clone_url,
            html_url:    .html_url,
            description: (.description // "No description")
          }
    ')

    if [[ ${#curlA[@]} -eq 0 ]]; then
        echo -e "${red}[X]${endColour} No repositories found for ${exploitCVE} in language ${exploitLang}."
        log "WARN" "No results for $exploitCVE / $exploitLang"
        exit 0
    fi

    echo -e "${green}[+]${endColour} Found ${#curlA[@]} repositor$([ ${#curlA[@]} -eq 1 ] && echo y || echo ies)."
    log "INFO" "Found ${#curlA[@]} repos for $exploitCVE in $exploitLang"
}

# ─────────────────────────────────────────────
# Interactive repository selector (FIX 8)
# ─────────────────────────────────────────────
function selectRepos(){
    echo ""
    echo -e "${yellow}══════════════════════════════════════════════════════${endColour}"
    echo -e "${yellow}  Repositories found for ${exploitCVE} [${exploitLang}]${endColour}"
    echo -e "${yellow}══════════════════════════════════════════════════════${endColour}"

    local i=1
    for entry in "${curlA[@]}"; do
        local stars lang pushed desc url
        stars=$(echo "$entry"  | jq -r '.stars')
        lang=$(echo "$entry"   | jq -r '.language')
        pushed=$(echo "$entry" | jq -r '.pushed' | cut -c1-10)
        desc=$(echo "$entry"   | jq -r '.description' | cut -c1-80)
        url=$(echo "$entry"    | jq -r '.html_url')

        echo -e "  ${purple}[$i]${endColour} ${green}⭐ $stars${endColour} | ${gray}$lang${endColour} | last push: $pushed"
        echo -e "       ${gray}$desc${endColour}"
        echo -e "       ${gray}$url${endColour}"
        echo ""
        (( i++ ))
    done

    echo -e "${yellow}══════════════════════════════════════════════════════${endColour}"
    echo -e "${gray}Enter the numbers of the repos to download (e.g. 1 3 5), or press Enter to download all:${endColour}"
    read -r -p "Selection: " selection

    if [[ -z "$selection" ]]; then
        # Keep all entries
        log "INFO" "User selected all ${#curlA[@]} repos."
        return
    fi

    # Filter curlA to only the selected indices
    local selected=()
    for idx in $selection; do
        if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#curlA[@]} )); then
            selected+=("${curlA[$((idx-1))]}")
        else
            echo -e "${red}[!]${endColour} Ignoring invalid index: $idx"
        fi
    done

    if [[ ${#selected[@]} -eq 0 ]]; then
        echo -e "${red}[X]${endColour} No valid selection made. Exiting."
        log "WARN" "User made no valid selection."
        exit 0
    fi

    curlA=("${selected[@]}")
    log "INFO" "User selected ${#curlA[@]} repo(s): $selection"
    echo -e "${green}[+]${endColour} Downloading ${#curlA[@]} repo(s)..."
}

# ─────────────────────────────────────────────
# SCP transfer
# ─────────────────────────────────────────────
function runSCP(){
    # FIX 3: parameters now clearly named; caller passes $exploitUser / $exploitTarget
    local scp_user="$1"
    local scp_target="$2"
    local src_dir="$3"
    local archive_name="$4"

    if [[ -z "$scp_user" || -z "$scp_target" ]]; then
        echo -e "${red}[X]${endColour} SCP mode requires both -u [user] and -t [target]."
        log "ERROR" "SCP called without user or target."
        exit 1
    fi

    echo -e "${yellow}[i]${endColour} Sending ${archive_name}.tar.gz → ${scp_user}@${scp_target}:/home/${scp_user}/ ..."
    log "INFO" "SCP: $src_dir/$archive_name.tar.gz → $scp_user@$scp_target"

    if scp -r "${src_dir}/${archive_name}.tar.gz" "${scp_user}@${scp_target}:/home/${scp_user}/" &>/dev/null; then
        echo -e "${green}[+]${endColour} SCP complete — file is in /home/${scp_user}/ on ${scp_target}."
        log "INFO" "SCP succeeded for $archive_name to $scp_target"
    else
        echo -e "${red}[X]${endColour} SCP failed. Check connectivity to ${scp_target}."
        log "ERROR" "SCP failed for $archive_name to $scp_target"
        exit 1
    fi
}

# ─────────────────────────────────────────────
# HTTP server (FIX 10: Python instead of nc)
# ─────────────────────────────────────────────
function runHTTP(){
    local repo_source="$1"
    local archive_name="$2"
    local src_dir="$3"

    # Gather network info
    networkC=$(ip r | grep -v default | grep metric | awk -F"dev" '{print $2}' | awk -F"proto" '{print $1}' | xargs 2>/dev/null || true)
    networkCard=($networkC)
    myIPAddress=$(ip r | grep -v default | grep metric | awk -F"src" '{print $2}' | awk -F"metric" '{print $1}' | xargs 2>/dev/null || true)
    myIP=($myIPAddress)

    echo -e "${gray}[i] To download ${archive_name} on the target machine:${endColour}"
    local ctr=0
    for iface in "${networkCard[@]}"; do
        echo -e "    ${purple}[$iface]${endColour} ${green}wget http://${myIP[$ctr]}:${portToDeploy}/${archive_name}.tar.gz${endColour}"
        echo -e "             ${green}curl -O http://${myIP[$ctr]}:${portToDeploy}/${archive_name}.tar.gz${endColour}"
        (( ctr++ ))
    done

    # FIX 10: Python HTTP server — portable and reliable across distros
    (cd "$src_dir" && python3 -m http.server "$portToDeploy" &>/dev/null) &
    local srv_pid=$!
    pidToDelete="$pidToDelete $srv_pid"
    log "INFO" "HTTP server PID $srv_pid on port $portToDeploy serving $archive_name"

    portToDeploy=$(( portToDeploy + 1 ))
}

# ─────────────────────────────────────────────
# Main download loop
# ─────────────────────────────────────────────
function mainFunction(){
    for entry in "${curlA[@]}"; do
        exportRepo=$(echo "$entry" | jq -r '.clone_url')
        repoSource=$(echo "$exportRepo" | awk -F".com/" '{print $2}' | awk -F".git" '{print $1}')
        userSource=$(echo "$repoSource" | awk -F"/" '{print $1}')

        echo -e "${yellow}[*]${endColour} Cloning ${purple}${repoSource}${endColour}..."
        log "INFO" "Cloning $exportRepo"

        # FIX 9: check git clone result before continuing
        if ! git clone "$exportRepo" "${downloadTarget}/${userSource}" &>/dev/null; then
            echo -e "${red}[!]${endColour} Failed to clone ${exportRepo}. Skipping."
            log "WARN" "git clone failed for $exportRepo — skipping."
            continue
        fi

        cd "$downloadTarget" &>/dev/null
        tar -zcf "${userSource}.tar.gz" "$userSource" &>/dev/null
        rm -rf "$userSource" &>/dev/null
        cd - &>/dev/null

        echo -e "${green}[+]${endColour} Archived → ${downloadTarget}/${userSource}.tar.gz"
        log "INFO" "Archived $userSource.tar.gz"

        if [[ "$exploitMode" == *"SCP"* ]]; then
            # FIX 3: use the correct global variables, not undefined $userName / $target
            runSCP "$exploitUser" "$exploitTarget" "$downloadTarget" "$userSource"
        elif [[ "$exploitMode" == *"HTTP"* ]]; then
            runHTTP "$repoSource" "$userSource" "$downloadTarget"
        elif [[ "$exploitMode" == *"Download"* ]]; then
            echo -e "${green}[+]${endColour} Saved to ${downloadTarget}/${userSource}.tar.gz"
        else
            echo -e "${red}[X]${endColour} Unknown mode '${exploitMode}'. Use Download, SCP, or HTTP."
            log "ERROR" "Unknown mode: $exploitMode"
            exit 1
        fi

        counter=$(( counter + 1 ))
        if [ "$counter" -gt "$maxResults" ]; then
            break
        fi
    done
}

# ─────────────────────────────────────────────
# Cleanup / end
# ─────────────────────────────────────────────
function endFunction(){
    if [[ -z "$pidToDelete" ]]; then
        echo -e "${green}[+]${endColour} Job finished. Files are in ${downloadTarget}/."
        echo -e "${gray}    Log: ${LOGFILE}${endColour}"
        log "INFO" "Session finished cleanly."
    else
        echo -ne "${yellow}[i]${endColour} HTTP servers will be killed in 2 minutes"
        for _ in {1..60}; do
            sleep 2s
            echo -ne "."
        done
        # shellcheck disable=SC2086
        kill -9 $pidToDelete &>/dev/null || true
        echo -e " ${green}(V)${endColour}"
        log "INFO" "HTTP servers killed: $pidToDelete"
    fi
}

function ctrl_c(){
    echo -ne "\n${yellow}[i]${endColour} Caught CTRL+C — cleaning up..."
    if [[ -z "$pidToDelete" ]]; then
        echo -e " ${green}(V)${endColour}"
        log "INFO" "Script interrupted by user. No HTTP servers to kill."
    else
        echo -e "\n${yellow}[!]${endColour} Killing HTTP servers..."
        # shellcheck disable=SC2086
        kill -9 $pidToDelete &>/dev/null || true
        echo -e "HTTP servers killed."
        log "INFO" "HTTP servers killed on CTRL+C: $pidToDelete"
    fi
    exit 0
}

# ─────────────────────────────────────────────
# Entry point
# FIX 12: root is only required for depsCheck (apt-get).
#          The rest of the script runs as any user.
# ─────────────────────────────────────────────
declare -i paramsC=0

# FIX 2: -h has no colon (does not take an argument)
while getopts ":e:l:m:n:u:t:z:h" arg; do
    case $arg in
        e) exploitCVE="$OPTARG";  (( paramsC++ )) ;;
        l) exploitLang="$OPTARG"; (( paramsC++ )) ;;
        m) exploitMode="$OPTARG"; (( paramsC++ )) ;;
        n) maxResults="$OPTARG"   ;;
        u) exploitUser="$OPTARG"  ;;
        t) exploitTarget="$OPTARG";;
        z) exploitNoDep="$OPTARG" ;;
        h) helpView ;;
        :) echo -e "${red}[X]${endColour} Option -$OPTARG requires an argument."; exit 1 ;;
        \?) echo -e "${red}[X]${endColour} Unknown option: -$OPTARG"; exit 1 ;;
    esac
done

if [ "$paramsC" -ne 3 ]; then
    helpView
fi

# Clamp maxResults
if (( maxResults < 1 || maxResults > 10 )); then
    echo -e "${yellow}[!]${endColour} -n must be between 1 and 10. Defaulting to 10."
    maxResults=10
fi

# Dependency check requires root (apt-get), but only if explicitly requested
if [[ "$exploitNoDep" == "on" ]]; then
    if [ "$(id -u)" != "0" ]; then
        echo -e "${red}[X]${endColour} Dependency installation (-z on) requires root."
        exit 1
    fi
    depsCheck
fi

preparation    # Set up output dir and log file
checkCVE       # Validate CVE format (and normalise to uppercase)
searchCVE      # Query GitHub API with pagination and metadata
selectRepos    # Interactive repository selector
mainFunction   # Clone, archive, and deliver repos
endFunction    # Cleanup HTTP servers / show summary
