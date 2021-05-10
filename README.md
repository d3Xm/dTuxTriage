# dTuxTriage

dTuxTriage is a tool for incident response triage of linux systems based on the work of Recruit-CSIRT.
it will gather essential information from the system and supports dumping memory aswell as creating a volatility profile for the memdump.

dTuxTriage has been tested on:
Debian: 10.8
Ubuntu: 20.04, 16.04
Rhel: 8.3

# Usage

1. Set the optional flags according to your use-case
## FLAG options
HASHFLAG=1                              ###### HashFlag 1=enable : get binary hash
CLAMAVFLAG=0                            ###### clamavFlag 1= install clamav and scan full

RKHUNTERFLAG=1                          ###### rkhunterFlag 1= install rkhunter and scan
MESSAGEFLAG=1                           ###### messageFlag 1= collect /var/log/messages and syslog (eg: mail log)
BACKUPFLAG=1                            ###### BACKUPFLAG 1= copy web server conf, contents for backup
MEMDUMPFLAG=1                           ###### MEMDUMPFLAG 1= isntall LiME kernel module and dump memory
DEBIANFLAG=1				                        ###### DEBIANFLAG 1= installs make, linux-headers, gcc and adds repository universe
RHELFLAG=0 				                         ###### RHELFLAG 1= installs make, kernel-headers, kernel-devel, gcc

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
