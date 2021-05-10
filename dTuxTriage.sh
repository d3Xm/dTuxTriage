#!/bin/bash

# dTuxTriage
# Date: 2021.05.10
# Version: 0.9
# usage: sudo bash dTuxTriage.sh , be sure to set the DEBIAN or RHEL flag if using the MEMDUMP flag.
# Licence: MIT

[[ $UID == 0 || $EUID == 0 ]] || (
  echo "Must be root! Please execute after 'su -' OR with 'sudo' . "
  exit 1
  ) || exit 1


### dynamic Configs
WEBROOT=()
WEBSERVICE=()
WEBROOT+=/var/www/html                                                 ###### web server document root dir (IF YOU ALREADY KNOW, Please ADD)
WEBSERVICE+=                                                           ###### web server installed directory (IF YOU ALREADY KNOW, Please ADD)
STARTDATE=$((`date -I | cut -d"-" -f1`-1))-`date -I | cut -d"-" -f2,3` ###### start date score for getting log rotation file (DEFAULT 1 year ago) except for boot.log,kern.log,auth.log
ENDDATE=`date -I | cut -d"-" -f1,2`-$((`date -I | cut -d"-" -f3`+1))   ###### end date score for getting log rotation file ( TODAY ) except for boot.log,kern.log,auth.log
###

### static Configs 
EXCLUDES_PATHS=./options/excludes.txt   ###### exclude paths from the directory listing. Each path should be on a new line.
SaveCWD=1                               ###### SAVE OUTPUT FILE TO WORKING DIRECTORY (SAME AS SCRIPT) 
STORAGETEST=1                           ###### STORAGE TEST VARIABLES : STORAGETEST: 1=enable
MINSPACE=1000000                        ###### MINSPACE(KB): Set to minimum number of KB required to keep temp files locally
IRCASE=`hostname`                       ###### basename of results archive
LOC=/tmp/$IRCASE                        ###### output destination, change according to needs
TMP=$LOC/$IRCASE'-tmp.txt'              ###### tmp file to redirect results
ERROR_LOG=$LOC/0_SCRIPT-ERRORS.txt      ###### redirect stderr and Debug echo
PHPBACKDOOR=./options/backdoorscan.php  ###### phpbackdoor script
## FLAG options
HASHFLAG=1                              ###### HashFlag 1=enable : get binary hash
CLAMAVFLAG=0                            ###### clamavFlag 1= install clamav and scan full
RKHUNTERFLAG=1                          ###### rkhunterFlag 1= install rkhunter and scan
MESSAGEFLAG=1                           ###### messageFlag 1= collect /var/log/messages and syslog (eg: mail log)
BACKUPFLAG=1                            ###### BACKUPFLAG 1= copy web server conf, contents for backup
MEMDUMPFLAG=1                           ###### MEMDUMPFLAG 1= installs LiME kernel module and dump memory
DEBIANFLAG=1				###### DEBIANFLAG 1= installs make, linux-headers, gcc and adds repository universe
RHELFLAG=0 				###### RHELFLAG 1= installs make, kernel-headers, kernel-devel, gcc



check_tmpstorage(){
	if [ "$STORAGETEST" = "1" ] ; then
		echo -e "\n[Debug][check_tmpstorage] check /tmp storage is enough ..."
		DF=$(df /tmp | grep dev | awk '{print $4}')
		echo -e 'Disk space available = '$DF''
		MEM=$(free | grep Mem| awk '{print $2}')
		echo -e 'Memory-dump will consume = '$MEM''
		MIN_REQ=$(($MINSPACE + $MEM))
		echo -e 'estimated minimum required space = '$MIN_REQ''
		echo -e '\n[Debug][check_tmpstorage] totally atleast '$MIN_REQ' memory/storage will be used'
		if [[ "$DF" -lt "$MIN_REQ" ]]; then
			echo 'Only '$DF' available when needed atleast '$MIN_REQ' available. Exiting.'
			exit
		else
			echo 'Available storage is '$DF' which is enough for '$MIN_REQ' so lets keep goin!'
		fi

	elif [ "$STORAGETEST" = "0" ] ; then
		echo -e 'STORAGETEST = '$STORAGETEST' -> NOT Enabled'
	else
		echo 'some error occured'
		exit
	fi
}



excludes_paths(){
    # To exclude paths from the directory listing, provide a file called
    EXCLUDES="-path /var/cache -o -path /var/spool"
    if [ -f $EXCLUDES_PATHS ]; then
        while read line
        do
            EXCLUDES="$EXCLUDES -o -path $line"
        done <$EXCLUDES_PATHS
    fi
    echo -e "\n[Debug][excludes_paths] set excludes_paths [$EXCLUDES]..."
}


prepare(){
    mkdir $LOC
    touch $ERROR_LOG
    echo -e "\n[Debug][prepare] mkdir "$LOC"\n"
} 2> /dev/null

get_userprofile(){
    # userprofile
    mkdir $LOC/Dir_userprofiles
    while read line
    do
        user=`echo "$line" | cut -f1 -d:`
        home=`echo "$line" | cut -f6 -d:`
        mkdir $LOC/Dir_userprofiles/$user        
        # user shell history
        echo -e "\n[Debug][userprofile][$user] get user shell history ... to Dir_userprofiles/$user/shellhistory.txt"
        for f in $home/.*_history; do
            count=0
            while read line
            do
                echo $f $count $line >> $LOC/Dir_userprofiles/$user/$IRCASE'-shellhistory.txt'
                echo $f $count $line >> $LOC/Dir_userprofiles/$user/$IRCASE'-shellhistory.txt'
                count=$(( $count + 1 ))
            done < $f
        done        
        # user contabs
        echo -e "\n[Debug][userprofile][$user] get user crontabs ... to Dir_userprofiles/$user/crontab.txt"
        crontab -u $user -l > $LOC/Dir_userprofiles/$user/$IRCASE'-crontab.txt'
        # ssh known hosts
        echo -e "\n[Debug][userprofile][$user] get ssh known hosts ... to Dir_userprofiles/$user/ssh_known_hosts.txt"
        cp -RH $home/.ssh/known_hosts $LOC/Dir_userprofiles/$user/$IRCASE'-ssh_known_hosts.txt'
        # ssh config
        echo -e "\n[Debug][userprofile][$user] get ssh config ... to Dir_userprofiles/$user/ssh_config.txt"
        cp -RH $home/.ssh/config $LOC/Dir_userprofiles/$user/$IRCASE'-ssh_config.txt'
	echo -e "\n[Debug][userprofile][$user] get .profile config ... to Dir_userprofiles/$user/profile.txt"
	cp -RH $home/.profile $LOC/Dir_userprofiles/$user/$IRCASE'-profile.txt'
	echo -e "\n[Debug][userprofile][$user] get .bashrc ... to Dir_userprofiles/$user/bashrc.txt"
	cp -RH $home/.bashrc $LOC/Dir_userprofiles/$user/$IRCASE'-bashrc.txt'
    done < /etc/passwd

    # user accounts
    echo -e "\n[Debug][userprofile] get user accounts ... to passwd.txt"
    cp -RH /etc/passwd $LOC/$IRCASE'-passwd.txt'

    # user groups
    echo -e "\n[Debug][userprofile] get user groups ... to group.txt"
    cp -RH /etc/group $LOC/$IRCASE'-group.txt'

    # user accounts
    {
        echo -e "\n[Debug][userprofile] get user shadows ... to shadow.txt"
        while read line
        do
            user=`echo "$line" | cut -d':' -f1`
            pw=`echo "$line" | cut -d':' -f2`
            # ignore the salt and hash, but capture the hashing method
            hsh_method=`echo "$pw" | cut -d'$' -f2`
            rest=`echo "$line" | cut -d':' -f3,4,5,6,7,8,9`
            echo "$user:$hsh_method:$rest"
        done < /etc/shadow
    } > $LOC/$IRCASE'-shadow.txt'
}

get_systeminfo(){
    # version information
    echo -e "\n[Debug][systeminfo] get version infomation ... to version.txt"
    {
        echo -n "kernel_name="; uname -s;
        echo -n "nodename="; uname -n;
        echo -n "kernel_release="; uname -r;
        echo -n "kernel_version="; uname -v;
        echo -n "machine="; uname -m;
        echo -n "processor="; uname -p;
        echo -n "hardware_platform="; uname -i;
        echo -n "os="; uname -o;

    } > $LOC/$IRCASE'-version.txt'

    # kernel modules
    echo -e "\n[Debug][systeminfo] get kernel modules ... to modules.txt"
    lsmod | sed 1d > $TMP
    while read module size usedby
    do
        {
            echo -e $module'\t'$size'\t'$usedby;
            modprobe --show-depends $module;
            modinfo $module;
            echo "";
        } >> $LOC/$IRCASE'-modules.txt'
    done < $TMP
    rm $TMP

    # list of PCI devices
    echo -e "\n[Debug][systeminfo] get PCI devices list ... to lspci.txt"
    if lspci &> /dev/null
    then
       LSPCI=`which lspci`
    fi
    $LSPCI > $LOC/$IRCASE'-lspci.txt'

    # locale information
    echo -e "\n[Debug][systeminfo] get locale info ... to locale.txt"
    locale > $LOC/$IRCASE'-locale.txt'

    # installed packages with version information - ubuntu
    echo -e "\n[Debug][systeminfo] get installed packages on ubuntu ... to package.txt"
    if dpkg-query -W &> /dev/null
    then
        dpkg-query -W -f='${Package}\t${Version}\n' > $LOC/$IRCASE'-packages.txt'
    fi
    # installed packages with version information - redhat/centos
    echo -e "\n[Debug][systeminfo] get installed packages on redhat/centos ... to package.txt"
    if /bin/rpm -qa --queryformat "%{NAME}\t%{VERSION}\n" &> /dev/null
    then
        /bin/rpm -qa --queryformat '%{NAME}\t%{VERSION}\n' >> $LOC/$IRCASE'-packages.txt'
    fi

    # kernel ring buffer messages
    echo -e "\n[Debug][systeminfo] get kernel ring buffer message [dmeg] ... to dmesg.txt"
    {
        if dmesg -T &> /dev/null
        then
            dmesg -T
        else
            dmesg
        fi
    } > $LOC/$IRCASE'-dmesg.txt' 

    # network interfaces
    echo -e "\n[Debug][systeminfo] get network interfaces [ifconfig] ... to ifconfig.txt"
    if [ -x /sbin/ifconfig ]
    then
        # rhel5
        IFCONFIG=/sbin/ifconfig
    else
        IFCONFIG=`which ifconfig`
    fi
    $IFCONFIG -a > $LOC/$IRCASE'-ifconfig.txt'   

    # mounted devices
    echo -e "\n[Debug][systeminfo]  Collecting information about currently mounted devices ... to mounted_devices.txt"
    mount > $LOC/$IRCASE_'lin-mounted_devices.txt'


}


get_activity(){
    # running processes
    echo -e "\n[Debug][activity] get running process [ps] ... to ps.txt"
    {
        PS_FORMAT=user,pid,ppid,vsz,rss,tname,stat,stime,time,args
        if ps axwwSo $PS_FORMAT &> /dev/null
        then
            # bsd
            ps axwwSo $PS_FORMAT
        elif ps -eF &> /dev/null
        then
            # gnu
            ps -eF
        else
            # bsd without ppid
            ps axuSww
        fi
    } > $LOC/$IRCASE'-ps.txt'

    # active network connections
    echo -e "\n[Debug][activity] get network conections [netstat] ... to netstat.txt"
    {
        if netstat -pvWanoee &> /dev/null
        then
            # gnu
            netstat -pvWanoee
        else
            # redhat/centos
            netstat -pvTanoee
        fi
    } > $LOC/$IRCASE'-netstat.txt'

    # active network infomation
    echo -e "\n[Debug][activity] get network informations [interface|ifconfig|ip|route|lsof|hosts] ... to netinfo.txt"
    {
        echo -e "\n</etc/network/interfaces>";cat /etc/network/interfaces
        echo  -e "\n<ifconfig -a>";ifconfig -a
        echo  -e "\n<ip addr>"; ip addr
        echo  -e "\n<ip link>";ip link
        echo  -e "\n<netstat -lnput>;"netstat -lnput
        echo  -e "\n<lsof -i -n -P>";lsof -i -n -P
        echo  -e "\n<ss -ap>";ss -ap
        echo  -e "\n<route -n>";route -n # "netstat -nr"; "ip route"
        echo  -e "\n<ip neigh>";ip neigh
        echo  -e "\n<cat /etc/hosts>";cat /etc/hosts
        echo  -e "\n<cat /etc/hosts.allow>";cat /etc/hosts.allow
        echo  -e "\n<cat /etc/hosts.deny>";cat /etc/hosts.deny
    } > $LOC/$IRCASE'-netinfo.txt'

    # current logged in users
    echo -e "\n[Debug][activity] get current logged in users ... to who.txt(\$who), who.bin(\$utmp)"
    if who -a &> /dev/null
    then
        who -a > $LOC/$IRCASE'-who.txt'
    else
        cat /var/run/utmp > $LOC/$IRCASE'-who.bin'
    fi
    # last logged in users
    echo -e "\n[Debug][activity] get last logged in users ... to last.txt"
    if last -Fwx -f /var/log/wtmp* &> /dev/null
    then
        last -Fwx -f /var/log/wtmp* > $LOC/$IRCASE'-last.txt'
    else
        cp -RH /var/log/wtmp* > $LOC/
    fi
    # last bad logon attempts
    echo -e "\n[Debug][activity] get last bad login-attempts ... to lastb.txt"
    if lastb -Fwx -f /var/log/btmp* &> /dev/null
    then
        last -Fwx -f /var/log/btmp* > $LOC/$IRCASE'-lastb.txt'
    else
        cp -RH /var/log/btmp* > $LOC/
    fi

}

get_fileinfo(){
    # list of open files
    if [ -x /usr/sbin/lsof ]
    then
        LSOF=/usr/sbin/lsof
    elif [ -x /sbin/lsof ]
    then
        LSOF=/sbin/lsof
    else
        LSOF=`which lsof`
    fi

    # list of open files, link counts
    echo -e "\n[Debug][fileinfo] get list of open files, link counts ... to linkcounts.txt"
    $LSOF +L > $LOC/$IRCASE'-lsof-linkcounts.txt'
    # list of open files, with network connection
    echo -e "\n[Debug][fileinfo] get list of open files, with network connection ... to netfiles.txt"
    $LSOF -i > $LOC/$IRCASE'-lsof-netfiles.txt'

    # directory listings
    # The listings are actually done through the 'find' command, not the
    # ls command. The '-xdev' flag prevents the script from walking directories on other file systems.
    echo -e "\n[Debug][fileinfo] get directory listings ... to ls.txt"
    echo -e "\n"$EXCLUDES
    {
        find / -xdev \( $EXCLUDES \) -prune -o -type f -printf '%C+\t%CZ\t' -ls;
    } > $LOC/$IRCASE'-ls.txt';

}

get_servicereg(){
    # list all services and runlevel
    echo -e "\n[Debug][servicereg] get list all services and runlevel ... to chkconfig.txt"
    if chkconfig -l &> /dev/null; then
        chkconfig -l > $LOC/$IRCASE'-chkconfig.txt'
    else
        chkconfig --list > $LOC/$IRCASE'-chkconfig.txt'
    fi
    # list all services and runlevel on ubuntu16 ~
    if sysv-rc-conf -list &> /dev/null; then
        sysv-rc-conf -list　>> $LOC/$IRCASE'-chkconfig.txt'
    else
        insserv -s　>> $LOC/$IRCASE'-chkconfig.txt'
    fi
    # list all services and runlevel on cent7 ~
    systemctl list-unit-files >> $LOC/$IRCASE'-chkconfig.txt'

22
    # cron
    echo -e "\n[Debug][servicereg] get cron information ... to cron*.txt"
    # users with crontab access
    cp -RH /etc/cron.allow $LOC/$IRCASE'-cronallow.txt'
    # users with crontab access
    cp -RH /etc/cron.deny $LOC/$IRCASE'-crondeny.txt'
    # crontab listing
    cp -RH /etc/crontab $LOC/$IRCASE'-crontab.txt'
    # cronfiles for services
    mkdir $LOC/Dir_cron.d
    cp -RH /etc/cron.d/* $LOC/Dir_cron.d/
    # cronfile listing
    ls -al /etc/cron.* > $LOC/$IRCASE'-cronfiles.txt'
}

get_logs(){
    # logs
    # SCOPE : STARTDATE ~ ENDDATE  find . -type f -name "*.php" -newermt "$STARTDATE" -and ! -newermt "$ENDDATE" -ls
    echo "LOG SCOPE: FROM "$STARTDATE" TO "$ENDDATE

    # httpd logs
    echo -e "\n[Debug][logs] get httpd log ... to Dir_httpdlogs"
    mkdir $LOC/Dir_httpdlogs
    if [ -d "/var/log/httpd/" ]; then
        find /var/log/httpd/ -name *access* -o -name *error* -newermt $STARTDATE -and ! -newermt $ENDDATE | xargs -I{} cp -RH {} $LOC/Dir_httpdlogs/ 
    fi
    # apache logs
    echo -e "\n[Debug][logs] get apache log ... to Dir_apachelogs"
    mkdir $LOC/Dir_apachelogs
    if [ -d "/var/log/apache2/" ] || [ -d "/var/log/apache/" ]; then
        find /var/log/apache* -name *access* -o -name *error* -newermt $STARTDATE -and ! -newermt $ENDDATE | xargs -I{} cp -RH {} $LOC/Dir_apachelogs/ 
    fi

    # auditD logs
    echo -e "\n[Debug][logs] get auditD log ... to Dir_auditDlogs"
    mkdir $LOC/Dir_auditDlogs
    if [ -d "/var/log/audit/" ]; then
	    find /var/log/audit/* -newermt $STARTDATE -and ! -newermt $ENDDATE | xargs -I{} cp -RH {} $LOC/Dir_auditDlogs/
    fi

    # nginx logs
    echo -e "\n[Debug][logs] get nginx log ... to Dir_nginxlogs"
    mkdir $LOC/Dir_nginxlogs
    if [ -d "/var/log/nginx/" ]; then
        find /var/log/nginx/ -name *access* -o -name *error* -newermt $STARTDATE -and ! -newermt $ENDDATE | xargs -I{} cp -RH {} $LOC/Dir_nginxlogs/ 
    fi

    # squid logs
    echo -e "\n[Debug][logs] get squid log ... to Dir_squidlogs"
    mkdir $LOC/Dir_squidlogs
    if [ -d "/var/log/squid/" ] || [ -d "/var/log/squid3/" ]; then
        find /var/log/squid* -name *access* -newermt $STARTDATE -and ! -newermt $ENDDATE | xargs -I{} cp -RH {} $LOC/Dir_squidlogs/ 
    fi

    # mysql & maria logs
    echo -e "\n[Debug][logs] get mysql & maria log ... to Dir_dblogs/mariadb"
    mkdir $LOC/Dir_dblogs
    if [ -d "/var/log/mariadb/" ]; then
        mkdir $LOC/Dir_dblogs/mariadb
        find /var/log/mariadb/* -newermt $STARTDATE -and ! -newermt $ENDDATE | xargs -I{} cp -RH {} $LOC/Dir_dblogs/mariadb/ 
    elif [ -d "/var/log/mysql/" ]; then
        mkdir $LOC/Dir_dblogs/mysqldb
        find /var/log/mysql/* -newermt $STARTDATE -and ! -newermt $ENDDATE | xargs -I{} cp -RH {} $LOC/Dir_dblogs/mysqldb/
    fi


    # boot logs
    echo -e "\n[Debug][logs] get boot log ... to Dir_bootlogs"
    mkdir $LOC/Dir_bootlogs
    find /var/log/boot* | xargs -I{} cp -RH {} $LOC/Dir_bootlogs/ 
    # kernel logs
    echo -e "\n[Debug][logs] get kernel log ... to Dir_kernlogs"
    mkdir $LOC/Dir_kernlogs    
    find /var/log/kern* | xargs -I{} cp -RH {} $LOC/Dir_kernlogs/ 
    # auth log
    echo -e "\n[Debug][logs] get auth log ... Dir_authlogs"
    mkdir $LOC/Dir_authlogs
    find /var/log/auth* | xargs -I{} cp -RH {} $LOC/Dir_authlogs/
    # security log
    echo -e "\n[Debug][logs] get security log ... Dir_securelogs"
    mkdir $LOC/Dir_securelogs
    find /var/log/secure* -newermt $STARTDATE -and ! -newermt $ENDDATE | xargs -I{} cp -RH {} $LOC/Dir_securelogs/ 
    # mail log
    echo -e "\n[Debug][logs] get mail log ... Dir_maillogs"
    mkdir $LOC/Dir_maillogs
    find /var/log/mail* -newermt $STARTDATE -and ! -newermt $ENDDATE | xargs -I{} cp -RH {} $LOC/Dir_maillogs/ 

    if [ "$MESSAGEFLAG" = "1" ] ; then
        echo -e "\n[Debug][logs] get message log ... Dir_messagelogs"
        mkdir $LOC/Dir_messagelogs
        find /var/log/ -name message* -o -name syslog* -newermt $STARTDATE -and ! -newermt $ENDDATE | xargs -I{} cp -RH {} $LOC/Dir_messagelogs/  # redhat / centos (message), ubuntu (syslog) 
    else
         echo -e 'MESSAGEFLAG = '$MESSAGEFLAG' -> NOT Enabled'  
    fi
}


get_iptables(){
	echo -e "\n[Debug][iptables] looking if iptables are installed  ... "
	if [ -f '/usr/sbin/iptables' ] ; then  
		echo -e "[Debug][iptables] iptables found ... "
		iptables -t filter -vL >> $LOC/$IRCASE'-iptables.txt'
		iptables -t nat -vL >> $LOC/$IRCASE'-iptables.txt'
		iptables -t mangle -vL >> $LOC/$IRCASE'-iptables.txt'
		iptables -t raw -vL >> $LOC/$IRCASE'-iptables.txt'
		iptables -t security -vL >> $LOC/$IRCASE'-iptables.txt'
		iptables -S >> $LOC/$IRCASE'-iptables-list.txt'
	else
		echo -e "[Debug][iptables] iptables NOT found"
	fi
}


get_srvconf(){
    # make output dir
    mkdir $LOC/Dir_srvconf

    # get webserver config: ex *.conf | /conf/ under web document root
    # WEB: apache, tomcat, 
    echo -e "\n[Debug][srvconf] get web server conf ... to Dir_srvconf and srvconfig.txt(list)"
    find ${WEBROOT[@]} ${WEBSERVICE[@]} \( -name '*.conf*' -o -name '*.xml' -o -name '*htaccess' -o \( -type d -name 'conf' \) \) -ls | awk '{print $11}' | xargs -I{} cp -RH --parents -rp {} $LOC/Dir_srvconf/  > $LOC/$IRCASE'-srvconfig.txt'
#    find ${WEBROOT[@]} ${WEBSERVICE[@]} \( -name '*.conf*' -o -name '*.xml' -o -name '*htaccess' -o \( -type d -name 'conf' \) \) -ls | xargs -I{} cp -RH --parents -rp {} $LOC/Dir_srvconf/  > $LOC/$IRCASE'-srvconfig.txt'

    # get db config
    # DATABASE : mysql & maria or postgres or oracle or maria
    echo -e "\n[Debug][srvconf] searching mysql db  ..."
    if type mysql > /dev/null 2>&1; then
        echo -e "[Debug][srvconf] mysql db found ... to Dir_srvconf and srvconfig.txt(list)"
        for i in `mysql --help | grep '/my.cnf' | tr ' ' '\n' `; do echo -e $i'\n' >> $LOC/$IRCASE'-srvconfig.txt';cp -RH --parents -rp $i $LOC/Dir_srvconf/; done
    else
    echo -e "[Debug][srvconf] mysql db NOT found"
    fi
    
    echo -e "\n[Debug][srvconf] searching postgres db  ... "
    if type psql > /dev/null 2>&1; then
        echo -e "[Debug][srvconf] postgres db found ... to Dir_srvconf and srvconfig.txt(list)"
        find /etc/postgresql* /var/lib/pgsql/* \( -name '*.conf*' -o -name '*.cnf*' \) -ls | awk '{print $11}' | xargs -I{} cp -RH --parents -rp {} $LOC/Dir_srvconf/  >> $LOC/$IRCASE'-srvconfig.txt'
    else
    echo -e "[Debug][srvconf] postgres db NOT found"
    fi
    

    ## Unverified
    echo -e "\n[Debug][srvconf] searching oracle db  ... "
    if [ -d '/usr/lib/oracle/' ]; then
        echo -e "[Debug][srvconf] oracle db found ... to Dir_srvconf and srvconfig.txt(list)"
        find /usr/lib/oracle/ \( -name '*.conf*' -o -name '*.cnf*' \)  -ls  | awk '{print $11}' | xargs -I{} cp -RH --parents -rp {} $LOC/Dir_srvconf/  >> $LOC/$IRCASE'-srvconfig.txt'  
    else
    echo -e "[Debug][srvconf] oracle db NOT found"
    fi
    
    ## Unverified
    echo -e "\n[Debug][srvconf] searching maria db  ... "
    if [ -d '/etc/my.cnf.d/' ]; then
        echo -e "[Debug][srvconf] maria db found ... to Dir_srvconf and srvconfig.txt(list)"
        find /etc/my.cnf.d/ \( -name '*.conf*' -o -name '*.cnf*' \) -ls  | awk '{print $11}' |  xargs -I{} cp -RH --parents -rp {} $LOC/Dir_srvconf/  >> $LOC/$IRCASE'-srvconfig.txt'  
    else
    echo -e "[Debug][srvconf] maria db NOT found"
    fi

    #PROXY: squid
    echo -e "\n[Debug][srvconf] searching squid proxy  ... "
    if [ -f '/usr/sbin/squid' ] || [ -f "/usr/sbin/squid3" ]; then      
        echo -e "[Debug][srvconf] squid proxy found ... to Dir_srvconf and srvconfig.txt(list)"
        find /etc/squid* \( -name '*.conf*' -o -name '*.cnf*' \) -ls  | awk '{print $11}' | xargs -I{} cp -RH --parents -rp {} $LOC/Dir_srvconf/  >> $LOC/$IRCASE'-srvconfig.txt'  
    else
    echo -e "[Debug][srvconf] squid proxy NOT found"
    fi

    #FTP: vsftpd
    echo -e "\n[Debug][srvconf] searching vsftpd  ... "
    if [ -f '/usr/sbin/vsftpd' ]; then       
        echo -e "[Debug][srvconf] vsftpd found ... "
        find /etc/vsftpd* \( -name '*.conf*' -o -name '*.cnf*' \) -ls | awk '{print $11}' | xargs -I{} cp -RH --parents -rp {} $LOC/Dir_srvconf/  >> $LOC/$IRCASE'-srvconfig.txt'  
    else
    echo -e "[Debug][srvconf] vsftpd NOT found"
    fi    

    ## Unverified
    #Mail:
    echo -e "\n[Debug][srvconf] searching mail  ... "
    if [ -f '/usr/share/misc/mail.rc' ] || [ -f ' /usr/local/etc/mail.rc' ] || [ -f '/etc/mail.rc' ] ; then  
        echo -e "[Debug][srvconf] mailserver config found ... "
        find /etc/ /usr/share/misc/ /usr/local/etc/ -name mail* -ls | xargs -I{} cp -RH --parents -rp {} $LOC/Dir_srvconf/  >> $LOC/$IRCASE'-srvconfig.txt'   
    else
    echo -e "[Debug][srvconf] mailserver config NOT found"
    fi

}    

get_srvcontents(){
    # make output dir
    mkdir $LOC/Dir_srvcontents

    echo -e "\n[Debug][srvcontents] get server contents "${WEBROOT[@]}"... to srvcontents.txt"
    find ${WEBROOT[@]} \( -name '*.php' -o -name '*.js' -o -name '*.py' -o -name '*.rb' -o  -name '*.go' -o -name '*.war' -o -name '*.pl' -o -name '*.cgi'  \) -ls | awk '{print $11}' | xargs -I{} cp -RH --parents -rp {} $LOC/Dir_srvcontents/  >> $LOC/$IRCASE'-srvcontents.txt'
    
    echo -e "\n[Debug][srvcontents] get suspicous executable ...( /tmp  "${WEBROOT[@]}") to susbin.txt"
    find ${WEBROOT[@]} -type f -exec file {}  \; | grep -E "(ELF|executable|PE32|shared object|script)"  >> $LOC/$IRCASE'-susbin.txt' 
    find /tmp -type f -exec file {}  \; | grep -E "(ELF|executable|PE32|shared object|script)"  >> $LOC/$IRCASE'-susbin.txt' 

}


scan_virus(){
    #pwd
    # backdoor scan
    echo -e "\n[Debug][virus] scan php backdoor ... to phpbackdoor.txt"    
    if [ ! -r $PHPBACKDOOR ]; then
        echo -e '\n file not exist : options/backdoorscan.php'
    elif type php > /dev/null 2>&1; then
        for item in ${WEBROOT[@]}; do
            php $PHPBACKDOOR $item >> $LOC/$IRCASE'-phpbackdoor.txt'
        done
    else
        echo -e '\n php does not installed. '   
    fi

    #clam av install and scan ref: https://www.clamav.net/documents/installing-clamav#requirements
    # https://www.clamav.net/documents/upgrading-clamav 
    echo -e "\n[Debug][virus] try to install and scan clam av ..."      
    if [ "$CLAMAVFLAG" = "1" ] ; then
	SAVED_PWD=$(pwd)
        echo -e "\n[Debug][virus] install and scan clam av ... to clamscan.txt"   
        tar -xzvf ./options/clamav-0.103.2.tar.gz 
        cd ./clamav-0.103.2
        ./configure with-user `whoami` with-group `whoami`
        make
        cd $SAVED_PWD

        # signiture 
        gpg --verify ./clamav-0.103.2.tar.gz.sig
        
        # [UPDATE] (if you connect to internet)
        # freshclam

        # virus scan
        clamscan -r -i / --exclude=".*\.core|.*\.snap"$ > $LOC/$IRCASE'-clamscan.txt'
	
	cd $SAVED_PWD
	
	#cd ./clamav-0.103.2
	#./configure
	#make uninstall


        #[remind] uninstall clamav
    else
        echo -e 'CLAMAVFLAG = '$CLAMAVFLAG' -> NOT Enabled' 
    fi 

    #rkhunter install and scan ref: http://rkhunter.sourceforge.net
    echo -e "\n[Debug][virus] try to install and scan rkhunter ..." 
    if [ "$RKHUNTERFLAG" = "1" ] ; then
	echo $(pwd)
	SAVED_PWD=$(pwd)	
        echo -e "\n[Debug][virus] install and scan rkhunter ... to rkhunter.txt"   
        tar -zxvf ./options/rkhunter-1.4.6.tar.gz; cd rkhunter-1.4.6
        ./installer.sh --install

        # [UPDATE] (if you connect to internet)
        #rkhunter --update
        #rkhunter --propupd

        # rootkit scan
        /usr/local/bin/rkhunter --check --skip-keypress --report-warnings-only > $LOC/$IRCASE'-rkhunter.txt'
        # white list: https://qiita.com/Peranikov/items/3f14476d0767d4589bcb
#	./rkhunter-1.4.6/installer.sh --remove
	echo $(pwd)
	cd $SAVED_PWD
	echo $(pwd)
	rm -rf rkhunter-1.4.6
    else
        echo -e 'RKHUNTERFLAG = '$RKHUNTERFLAG' -> NOT Enabled' 
    fi

}    

get_hash(){
    echo -e "\n[Debug][hash] try to get SHA256 hash value for bin ..." 
    if [ "$HASHFLAG" = "1" ] ; then
        echo -e "\n[Debug][hash] get SHA256 hash value for bin ... to binhashlist.txt" 
        cat $LOC/$IRCASE'-ls.txt' | rev | cut -d" " -f1 | rev | grep -e '/bin/' -e '/sbin/' | xargs -i sha256sum {}  > $LOC/$IRCASE'-binhashlist.txt' 
    else
        echo -e 'HASHFLAG = '$HASHFLAG' -> NOT Enabled' 
    fi
}






additional_backup(){
    echo -e "\n[Debug][backup] try to additional backup ... to Dir_backup, backup.txt(list)" 
    mkdir $LOC/Dir_backup
    mkdir $LOC/Dir_backup/CONFIG
    find / -type f \( -name *.conf -o -name *.cnf \) -ls | awk '{print $11}' | xargs -I{} cp -RH --parent -rp {} $LOC/Dir_backup/CONFIG
    find / -type f \( -name *.conf -o -name *.cnf \) -ls | awk '{print $11}' >> $LOC/$IRCASE'-backup.txt'
    find / -type d \( -name *conf* -o -name *config* \) -ls | awk '{print $11}' | xargs -I{} cp -RH --parent -rp {} $LOC/Dir_backup/CONFIG
    find / -type d \( -name *conf* -o -name *config* \) -ls | awk '{print $11}' >> $LOC/$IRCASE'-backup.txt'
    echo 'cp -RH --parents -rp /var/spool $LOC/Dir_backup/' >> $LOC/$IRCASE'-backup.txt'
    cp -RH --parents -rp /var/spool $LOC/Dir_backup/
    echo 'cp -RH --parents -rp /etc/cron* $LOC/Dir_backup/' >> $LOC/$IRCASE'-backup.txt'
    cp -RH --parents -rp /etc/cron* $LOC/Dir_backup/
    for item in ${WEBROOT[@]}; do
        echo 'cp -RH --parents -rp '$item' $LOC/Dir_backup/' >> $LOC/$IRCASE'-backup.txt'
        cp -RH --parents -rp $item $LOC/Dir_backup/ >> $LOC/$IRCASE'-backup.txt'
    done
    echo -e "\n[Debug][backup] backup func FIN ..." 
}


get_rhelconfig(){
    echo -n "[Debug][rhelconfig] installing rhel dependancies"
    if [ "$RHELFLAG" = "1" ] ; then
        yum -y install make kernel-headers kernel-devel gcc libdwarf-tools zip libelf-dev libelf-devel
	SAVED_PWD=$(pwd)
	mkdir dwarf
	cd dwarf
	../options/libdwarf_source/configure
	make
	cd dwarfdump
	export PATH=$PATH:$(pwd)
	cd $SAVED_PWD
    else
        echo -e 'REHELFLAG = '$REHELFLAG' -> NOT Enabled' 
    fi
}

get_debianconfig(){
    echo -n "[Debug][debianconfig] installing debian dependancies"
    if [ "$DEBIANFLAG" = "1" ] ; then
        
        apt-get -y install make linux-headers-$(uname -r) gcc dwarfdump zip
    else
        echo -e 'DEBIANFLAG = '$DEBIANFLAG' -> NOT Enabled'
    fi   
}

get_memdump(){
    if [ "$MEMDUMPFLAG" = "1" ] ; then
	echo -e "\n[Debug][memdump] initiating memdump function .."
	SAVED_PWD=$(pwd)
	echo $SAVED_PWD
	echo -e "\n[Debug][memdump] saving cwd as '$SAVED_PWD' .."
	echo -e "\n[Debug][memdump] compiling LiME Kernel Module ..."
	rm -f /tmp/lime.tar
	cp ./options/lime.tar /tmp/
	pushd /tmp/
	tar -xvf /tmp/lime.tar; cd /tmp/LiME-1.9.1/src
	make
	mv lime-*.ko /tmp/lime.ko
	echo -e "\n[Debug][memdump] Inserting LiME module and creating memory image ..."
	insmod /tmp/lime.ko "path=/tmp/memdump.lime format=lime"
	echo -e "\n[Debug][memdump] Cleanup after LiME Kernel Module compilation and removing module ..."
	rmmod lime
	rm -f /tmp/lime.tar
	rm -rf /tmp/LiME-1.9.1/
	rm -f /tmp/lime.ko
	cp /tmp/memdump.lime $LOC/$IRCASE'-memdump.lime'
	rm -f /tmp/memdump.lime
	cd $SAVED_PWD
	NEW_CWD=$(pwd)
	echo $NEW_CWD
	echo -e "\n[Debug][memdump] verifying cwd '$NEW_CWD' .. "
    else
	    echo -e "MEMDUMPFLAG = '$MEMDUMPFLAG' -> NOT ENABLED"
    fi
}


get_memprofile(){
	if [ "$MEMDUMPFLAG" = "1" ] ; then
		echo -e "\n[Debug][memprofile] initating process to create memory profile "
		SAVED_PWD=$(pwd)
		cd options/volatility_tools/ && make
		zip $(lsb_release -i -s)_$(uname -r)_profile.zip module.dwarf /boot/System.map-$(uname -r)
		mv $(lsb_release -i -s)_$(uname -r)_profile.zip $LOC
		cd $SAVED_PWD
		rm -rf dwarf
	else
		echo -e "\n[Debug][memprofile] "MEMDUMPFLAG" = '$MEMDUMPFLAG' -> NOT ENABLED"
	fi
	
}


######################   MAIN    ##########################
{
    check_tmpstorage 2>&1
    excludes_paths 2>&1
    prepare 2>&1
} 

# start timestamp
date '+%Y-%m-%d %H:%M:%S %Z %:z' > $LOC/$IRCASE'-date.txt'

### Detect WEBROOT and WEBSERVICE
echo -e "\n[Debug] Detect ( WEBROOT and WEBSERVICE ) PATH ... STATIC CONF << ( "${WEBROOT[@]}" and "${WEBSERVICE[@]}" )."

{
    echo "##############  DEBUG & ERROR LOGS START ####################"

    echo -e "\n[Debug][httpd] Searching WebROOT and WEBSERVICE."
    WEBCONF_HTTPD=`httpd -V | grep "SERVER_CONFIG_FILE" | cut -d"=" -f2 | xargs`
    if [ ${#WEBCONF_HTTPD} -gt 1 ]; then
        echo -e "[Debug] httpd FOUND (installed)"
        HTTPD=`httpd -V | grep "HTTPD_ROOT" | cut -d"=" -f2 | xargs`
        if [ ${WEBCONF_HTTPD:zero:1} != "/" ]; then
            WEBCONF_HTTPD=$HTTPD/$WEBCONF_HTTPD
        fi        
        WEBSERVICE+=( $HTTPD )
        WEBROOT+=( `grep -v "#" $WEBCONF_HTTPD | grep DocumentRoot | cut -d" " -f2 | xargs` )
        iWEBROOT+=( `grep -v "#" $WEBCONF_HTTPD | grep -i include | grep conf | cut -d" " -f2 | xargs cat | grep DocumentRoot | cut -d" " -f2 | xargs` )
        HTTPD_WILDCONF=`grep -v "#" $WEBCONF_HTTPD | grep -i include | grep conf |grep "\*" | cut -d" " -f2 | xargs`
        if [ ${#HTTPD_WILDCONF} -gt 1 ]; then
            WEBROOT+=( `grep -v "#" $HTTPD_WILDCONF | grep DocumentRoot | cut -d" " -f2 | xargs` )
        fi
    fi

    echo -e "\n[Debug][apache2] Searching WebROOT and WEBSERVICE."
    WEBCONF_APACHE2=`apache2ctl -V | grep "SERVER_CONFIG_FILE" | cut -d"=" -f2 | xargs`
    if [ ${#WEBCONF_APACHE2} -gt 1 ]; then
        echo -e "[Debug] apache2 FOUND (installed)"
        APACHE2=`apache2ctl -V | grep "HTTPD_ROOT" | cut -d"=" -f2 | xargs`
        if [ ${WEBCONF_APACHE2:zero:1} != "/" ]; then
            WEBCONF_APACHE2=$APACHE2/$WEBCONF_APACHE2
        fi
        WEBSERVICE+=( $APACHE2 )
        WEBROOT+=( `grep -v "#" $WEBCONF_APACHE2 | grep "Options Indexes" -B1 | grep Directory | sed -e "s/^.*<Directory \(.*\)>.*$/\1/" | xargs` )  
        APACHE2_INCLUDE=`grep -v "#" $WEBCONF_APACHE2 | grep -i include | grep conf | cut -d" " -f2 | xargs`
        if [ ${#APACHE2_INCLUDE} -gt 1 ]; then  
            WEBROOT+=( `cat $APACHE2_INCLUDE | grep -v "#" | grep "Options Indexes" -B1 | grep Directory | sed -e "s/^.*<Directory \(.*\)>.*$/\1/" | xargs`)
        fi
    fi

    echo -e "\n[Debug][nginx] Searching WebROOT and WEBSERVICE."
    WEBCONF_NGINX=`nginx -V 2>&1 1>/dev/null | grep "configure arguments" | sed -e "s/^.*--conf-path=\(.*\)conf.*$/\1/" | xargs`'conf'
    if [ ${#WEBCONF_NGINX} -gt 1 ]; then
        echo -e "[Debug] nginx FOUND (installed)"
        WEBROOT+=( `grep -v "#" $WEBCONF_NGINX | grep root | sed -e "s/^.*root\(.*\);.*$/\1/" | grep "/" | xargs` )
        WEBROOT+=( `grep -v "#" $WEBCONF_NGINX | grep -i include | grep conf | sed -e "s/^.*include\(.*\);.*$/\1/" | grep "/" | xargs cat | grep -v "#" | grep root | sed -e "s/^.*root\(.*\);.*$/\1/" | xargs` )
        NGINX_WILDCONF=`grep -v "#" $WEBCONF_NGINX | grep -i include | grep conf  | sed -e "s/^.*include\(.*\);.*$/\1/" | grep "\*" | cut -d" " -f2`
        if [ ${#NGINX_WILDCONF} -gt 1 ]; then
            WEBROOT+=( `grep -v "#" $NGINX_WILDCONF | grep root | sed -e "s/^.*root\(.*\);.*$/\1/" | grep "/" | xargs` )    
        fi
    fi

    echo -e "\nRESULT WEBROOTs: ["${WEBROOT[@]}"]"
    echo -e "RESULT WEBSERVICEs: ["${WEBSERVICE[@]}"]" 
} >> $ERROR_LOG


echo -e "\nRESULT WEBROOTs: ["${WEBROOT[@]}"]"
echo -e "RESULT WEBSERVICEs: ["${WEBSERVICE[@]}"]" 

echo -e "\n[Debug] Collect triage data  ..."
{
    get_debianconfig 2>&1
    get_rhelconfig 2>&1
    get_memdump 2>&1
    get_memprofile 2>&1
    get_userprofile 2>&1
    get_systeminfo 2>&1
    get_activity 2>&1
    get_fileinfo 2>&1   
    get_servicereg 2>&1
    get_logs 2>&1
    get_iptables 2>&1
    get_srvconf 2>&1
    get_srvcontents 2>&1
    scan_virus 2>&1    
    get_hash 2>&1
    echo -e "\n##############  DEBUG & ERROR LOGS END ####################"
} >> $ERROR_LOG


if [ "$BACKUPFLAG" = "1" ] ; then
    echo -e "\n[Debug] Back Up collection  ..."
    {
        additional_backup 2>&1
    } >> $ERROR_LOG
else
    echo -e 'BACKUPFLAG = '$BACKUPFLAG' -> NOT Enabled' 
fi

# tree of outputs 
{
 echo -e "\n[Debug] make OUTPUT-TREE  ..."
 if tree &> /dev/null; then
    tree -alh $LOC > $LOC/1_OUTPUT-TREE.txt
 else
    find $LOC | sort | sed '1d;s/^\.//;s/\/\([^/]*\)$/|--\1/;s/\/[^/|]*/| /g' > $LOC/1_OUTPUT-TREE.txt
 fi
}

echo -e "\n[Debug] Compress to tar.gz  ..."
CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $LOC
tar -zcvf "/tmp/"$IRCASE".tar.gz" * > /dev/null
cd $CUR_DIR

echo -e "\n[Debug] move tar.gz to here ..."
if [ "$SaveCWD" = "1" ] ; then
    mv "/tmp/"$IRCASE".tar.gz" $CUR_DIR
fi

# end timestamp
date '+%Y-%m-%d %H:%M:%S %Z %:z' >> $LOC/$IRCASE'-date.txt'

echo -e "\n[Debug] del /tmp file ..."
cd /tmp
rm -r $LOC

echo -e "\n[Debug] triage script END "
