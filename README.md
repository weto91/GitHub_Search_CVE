# GitHub_Search_CVE
### Features

- Search CVE exploits from github
- Download up to 10 CVE exploits at the same time automatically
- Send the exploits from SCP to a defined target
- Create HTTP server with the exploits to download it from another machine

# GitHub_Search_CVE

##Requirements
- Debian based operative system
- Tested on Kali  2022-01-31 and Ubuntu 20.04
- <b>git</b>: (Automatic installation from script)
- <b>curl</b>: (Automatic installation from script)
- <b>jq</b>: (Automatic installation from script)
- <b>netcat</b>: (Automatic installation from script)

##Installation
You dont need install nothing. It's a shell script =). You only need the sh file and run it!

## How to use
`# ./GitHubSearchCVE.sh -e [CVE-XXX-XXXX] -l [Python] -m [SCP] -u [user] -t [10.10.10.25]`
- <b>-e</b>: Specifies the CVE to search for. The string to be entered must have CVE format **
- <b>-l</b>: Specifies the language to filter. **
- <b>-m</b>: Specifies the mode tu run the script **
- <b>-u</b>: (Only needed if you have selected "SCP" mode) specifies the target username
- <b>-t</b>: (Only needed if you have selected "SCP" mode) specifies the target ip address

###### CVE Format
The CVE format must always start with the character sequence CVE followed by a hyphen. The next four digits will be the year in which the CVE was published, we will add another hyphen and finally we will enter the code of the vulnerability, this code can contain between 1 and 7 digits (although we usually find them with between 4 and 5 digits) . 

<b>Example:</b> CVE-2021-3156 or CVE‑2022‑24525
###### Valid languages
You can filter by any language available on GitHub. For exploits, the most typical languages are:
- Shell
- Python
- C
- Java
- JavaScript
- PHP
- Go
- Perl
- Ruby

###### Modes that you can run in this script
This script can work in three modes:
- <b>Download</b>: In this way, you will be able to search for the exploits and download them in  <b>/tmp/CVEDownloaded/</b>. You can read and try them to your liking.
- <b>SCP</b>: In this mode, the Download mode will be executed, once it is finished, the downloaded exploits will be sent by SCP to the home folder of the user specified with the <b>-u</b> option on the machine that we have specified with the <b>-t</b> option
- <b>HTTP</b>: There are times when we do not have full access to a user on the machine on which we want to launch the exploit. For example if the access we have to that machine is by LFI. For this type of case, we can use this mode, which allows us to create an HTTP 0.9 server on ports <b>8080-8089</b> of our computer, in order to be able to download using curl, wget, etc. from the remote machine.

###### How its works?
The script uses the GitHub URL API to search for the CVE we want filtering by language. For this we use jq, selecting only the clone_url and Language fields. Then, filtering the output and putting it into an array, we git clone each of the repositories, compress them into .tar.gz, calling each file after the developer that contains the repository.

In the case of selecting the SCP mode, the script will perform an SCP of all the repositories downloaded to the home of the user that we have defined on the machine that we will also have defined.

In HTTP mode, the script will netcat ports 8080 (for the first repository) up to 8089 (for the latest repository). Also appearing a message, with the command that you must enter in the machine that we are auditing to download the exploit and use it as we please.
This mode had a small problem, and that is that when launching netcat, the processes remained waiting, so the script launches them in the background, it also captures the PIDs of these processes so that, once two minutes have passed, these processes are terminated without the user having to interact with them manually.

