# dTuxTriage

dTuxTriage is a tool for incident response triage of linux systems based on the work of Recruit-CSIRT.<br />
It will swiftly gather essential information from the potentially compromised as well as scan for backdoors, rootkits hash files on disk and supports dumping memory aswell as creating a volatility profile for the memdump depending on what flags are set.<br />
The output will look like the following: <br />

<p align="center">
  <img width="2172" height="86" src="https://i.imgur.com/F74kXB5.png">
</p>

# dTuxTriage has been tested on: <br />
Debian: 10.8 <br />
Ubuntu: 20.04, 16.04 <br />
Rhel: 8.3 <br />

# Usage

Set the optional flags according to your use-case <br />
HASHFLAG=1 - get binary hash <br />
CLAMAVFLAG=0 - install clamav and scan full<br />
RKHUNTERFLAG=1 - install rkhunter and scan <br />
MESSAGEFLAG=1 - collect /var/log/messages and syslog (eg: mail log) <br />
BACKUPFLAG=1 - copy web server conf, contents for backup <br />
MEMDUMPFLAG=1 - install LiME kernel module and dump memory <br />
DEBIANFLAG=1 - installs make, linux-headers, gcc and adds repository universe <br />
RHELFLAG=0 - installs make, kernel-headers, kernel-devel, gcc <br />

`sudo ./dTuxTriage.sh`


# Planned changes:
Fix a proper working AV scan.

 
# Changes:

2021-05-10<br />
Fixed numerous small bugs and mispelled referals<br />
Added a new function to check for available diskspace and check the size of volatilememory and take that into account wether to run or not. <br />
Added function for memdump and creating a volatility profile<br />
Added flags for debian/rhel to install/use software needed to support memory dump<br />
Added newer version of RKhunter and ClamAV to the repository<br />
