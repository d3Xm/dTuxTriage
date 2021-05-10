# dTuxTriage

dTuxTriage is a tool for incident response triage of linux systems based on the work of Recruit-CSIRT.
it will gather essential information from the system and supports dumping memory aswell as creating a volatility profile for the memdump.

dTuxTriage has been tested on:
Debian: 10.8
Ubuntu: 20.04, 16.04
Rhel: 8.3


# Planned changes:
Fix a proper working AV scan.

 
# Changes:

2021-05-10
Fixed numerous small bugs and mispelled referals
Added new function to check for available space and check the size of memory and take that into account wether to run or not. 
Added function for memdump and creating a volatility profile
Added flags for debian/rhel to supp
Added newer version of RKhunter and ClamAV to the repository
