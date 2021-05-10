# dTuxTriage

dTuxTriage is a tool for incident response triage of linux systems based on the work of Recruit-CSIRT.
it will gather essential information from the system and supports dumping memory aswell as creating a volatility profile for the memdump.

dTuxTriage has been tested on:
Debian: 10.8
Ubuntu: 20.04, 16.04
Rhel: 8.3

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

2021-05-10
Fixed numerous small bugs and mispelled referals
Added new function to check for available space and check the size of memory and take that into account wether to run or not. 
Added function for memdump and creating a volatility profile
Added flags for debian/rhel to supp
Added newer version of RKhunter and ClamAV to the repository
