#!/usr/bin/env bash

# Author: Jon Schipp
# 2015-03-09 [Pascal Hegy] - Add sudo for linux
# 2015-03-09 [Pascal Hegy] - Change USER variable to USERNAME to avoid the use and confusion with the USER env variable
# 2017-08-30 [Roberto Leibman] - Reordered checks to make sure dead and inactive get checked first

########
# Examples:

# 1.) List services for osx
# $ ./check_service.sh -l -o osx
#
# 2.) Check status of SSH service on a linux machine
# $ ./check_service.sh -o linux -s sshd

# 3.) Manually select service management tool and service
# $ ./check_service.sh -o linux -t "service rsyslog status"

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Check status of system services for Linux, FreeBSD, OSX, and AIX.

     Options:
        -s <service>    Specify service name
        -l              List services
        -o <os>         OS type, "linux/osx/freebsd/aix"
        -u <user>       User if you need to ``sudo -u'' for launchctl (def: nagios, linux and osx only)
        -t <tool>       Manually specify service management tool (def: autodetect) with status and service
                        e.g. ``-t "service nagios status"''


EOF
}

argcheck() {
# if less than n argument
if [ $ARGC -lt $1 ]; then
        echo "Missing arguments! Use \`\`-h'' for help."
        exit 1
fi
}

os_check() {
if [ "$OS" == null ]; then
	unamestr=$(uname)
        if [[ $unamestr == 'Linux' ]]; then
                OS='linux'
        elif [[ $unamestr == 'FreeBSD' ]]; then
               OS='freebsd'
        elif [[ $unamestr == 'Darwin' ]]; then
               OS='osx'	       
        else
                echo "OS not recognized, Use \`-o\` and specify the OS as an argument"
                exit 3
        fi
fi
}



determine_service_tool() {
TRUST_EXIT_CODE=0
if [[ $OS == linux ]]; then
        if command -v systemctl >/dev/null 2>&1; then
                SERVICETOOL="systemctl status $SERVICE"
                LISTTOOL="systemctl"
                if [ $USERNAME ]; then
                    SERVICETOOL="sudo -u $USERNAME systemctl status $SERVICE"
                    LISTTOOL="sudo -u $USERNAME systemctl"
                fi
		TRUST_EXIT_CODE=1
        elif command -v initctl >/dev/null 2>&1; then
                SERVICETOOL="status $SERVICE"
                LISTTOOL="initctl list"
                if [ $USERNAME ]; then
                    SERVICETOOL="sudo -u $USERNAME status $SERVICE"
                    LISTTOOL="sudo -u $USERNAME initctl list"
                fi
        elif command -v service >/dev/null 2>&1; then
                SERVICETOOL="service $SERVICE status"
                LISTTOOL="service --status-all"
                if [ $USERNAME ]; then
                    SERVICETOOL="sudo -u $USERNAME service $SERVICE status"
                    LISTTOOL="sudo -u $USERNAME service --status-all"
                fi
        elif command -v chkconfig >/dev/null 2>&1; then
                SERVICETOOL=chkconfig
                LISTTOOL="chkconfig --list"
                if [ $USERNAME ]; then
                    SERVICETOOL="sudo -u $USERNAME chkconfig"
                    LISTTOOL="sudo -u $USERNAME chkconfig --list"
                fi
        elif [ -f /etc/init.d/$SERVICE ] || [ -d /etc/init.d ]; then
                SERVICETOOL="/etc/init.d/$SERVICE status | tail -1"
                LISTTOOL="ls -1 /etc/init.d/"
                if [ $USERNAME ]; then
                    SERVICETOOL="sudo -u $USERNAME /etc/init.d/$SERVICE status | tail -1"
                    LISTTOOL="sudo -u $USERNAME ls -1 /etc/init.d/"
                fi
        else
                echo "Unable to determine the system's service tool!"
                exit 1
        fi
fi

if [[ $OS == freebsd ]]; then
        if command -v service >/dev/null 2>&1; then
                SERVICETOOL="service $SERVICE status"
                LISTTOOL="service -l"
        elif [ -f /etc/rc.d/$SERVICE ] || [ -d /etc/rc.d ]; then
                SERVICETOOL="/etc/rc.d/$SERVICE status"
                LISTTOOL="ls -1 /etc/rc.d/"
        else
                echo "Unable to determine the system's service tool!"
                exit 1
        fi
fi

if [[ $OS == osx ]]; then
        if [ -f /usr/sbin/serveradmin >/dev/null 2>&1 ] && serveradmin list | grep "$SERVICE" 2>&1 >/dev/null; then
                SERVICETOOL="serveradmin status $SERVICE"
                LISTTOOL="serveradmin list"
        elif [ -f /Applications/Server.app/Contents/ServerRoot/usr/sbin/serveradmin >/dev/null 2>&1 ] && \
               /Applications/Server.app/Contents/ServerRoot/usr/sbin/serveradmin list | \
                grep "$SERVICE" 2>&1 >/dev/null; then
                SERVICETOOL="/Applications/Server.app/Contents/ServerRoot/usr/sbin/serveradmin status $SERVICE"
                LISTTOOL="/Applications/Server.app/Contents/ServerRoot/usr/sbin/serveradmin list"
        elif command -v launchctl >/dev/null 2>&1; then
                SERVICETOOL="launchctl list | grep -v ^- | grep $SERVICE || echo $SERVICE not running! "
                LISTTOOL="launchctl list"
                if [ $USERNAME ]; then
                        SERVICETOOL="sudo -u $USERNAME launchctl list | grep -v ^- | grep $SERVICE || echo $SERVICE not running! "
                        LISTTOOL="sudo -u $USERNAME launchctl list"
                fi
        elif command -v service >/dev/null 2>&1; then
                SERVICETOOL="service --test-if-configured-on $SERVICE"
                LISTTOOL="service list"
        else
                echo "Unable to determine the system's service tool!"
                exit 1
        fi
fi

if [[ $OS == aix ]]; then
        if command -v lssrc >/dev/null 2>&1; then
                SERVICETOOL="lssrc -s $SERVICE | grep -v Subsystem"
                LISTTOOL="lssrc -a"
        else
                echo "Unable to determine the system's service tool!"
                exit 1
        fi
fi
}

ARGC=$#
LIST=0
MANUAL=0
OS=null
SERVICETOOL=null
LISTTOOL=null
SERVICE=".*"
#USERNAME=nagios

argcheck 1

while getopts "hls:o:t:u:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 0
             ;;
         l)
             LIST=1
             ;;
         s)
             SERVICE="$OPTARG"
             ;;
         o)
             if [[ "$OPTARG" == linux ]]; then
                     OS="$OPTARG"
             elif [[ "$OPTARG" == osx ]]; then
                     OS="$OPTARG"
             elif [[ "$OPTARG" == freebsd ]]; then
                     OS="$OPTARG"
             elif [[ "$OPTARG" == aix ]]; then
                     OS="$OPTARG"
             else
                     echo "Unknown type!"
                     exit 1
             fi
             ;;
         t)
             MANUAL=1
             MANUALSERVICETOOL="$OPTARG"
             ;;
         u)
             USERNAME="$OPTARG"
             ;;
         \?)
             exit 1
             ;;
     esac
done

os_check

if [ $MANUAL -eq 1 ]; then
SERVICETOOL=$MANUALSERVICETOOL
else
determine_service_tool
fi

# -l conflicts with -t                                                                                                                                                   
if [ $MANUAL -eq 1 ] && [ $LIST -eq 1 ]; then
    echo "Options conflict: \`\`-t'' and \`\`-l''"
    exit 2
fi

if [ $LIST -eq 1 ]; then
        if [[ $LISTTOOL != null ]]; then
                $LISTTOOL
                exit 0
        else
                echo "OS not specified! Use \`\`-o''"
                exit 2
        fi
fi

# Check the status of a service
STATUS_MSG=$(eval "$SERVICETOOL" 2>&1)
EXIT_CODE=$?

## Exit code from the service tool - if it's non-zero, we should
## probably return CRITICAL.  (though, in some cases UNKNOWN would
## probably be more appropriate)
[ $EXIT_CODE -ne 0 ] && echo "$STATUS_MSG" && exit $CRITICAL

## For systemd and most systems, $EXIT_CODE can be trusted - if it's 0, the service is running.
## Ref https://github.com/jonschipp/nagios-plugins/issues/15
[ $TRUST_EXIT_CODE -eq 1 ] && [ $EXIT_CODE -eq 0 ] && echo "$STATUS_MSG" && exit $OK 

case $STATUS_MSG in

*stop*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*STOPPED*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*not*running*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*inactive*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*dead*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*running*)
        echo "$STATUS_MSG"
        exit $OK
        ;;
*RUNNING*)
        echo "$STATUS_MSG"
        exit $OK
        ;;
*SUCCESS*)
        echo "$STATUS_MSG"
        exit $OK
        ;;
*[eE]rr*)
        echo "Error in command: $STATUS_MSG"
        exit $CRITICAL
        ;;
*[fF]ailed*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*[eE]nable*)
        echo "$STATUS_MSG"
        exit $OK
        ;;
*[dD]isable*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*[cC]annot*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*[aA]ctive*)
        echo "$STATUS_MSG"
        exit $OK
        ;;
*Subsystem*not*on*file)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
[1-9][0-9]*)
        echo "$SERVICE running: $STATUS_MSG"
        exit $OK
        ;;
"")
	echo "$SERVICE is not running: no output from service command"
	exit $CRITICAL
	;;
*)
        echo "Unknown status: $STATUS_MSG"
        echo "Is there a typo in the command or service configuration?: $STATUS_MSG"
        exit $UNKNOWN
        ;;
esac

