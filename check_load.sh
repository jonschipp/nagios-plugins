#!/usr/bin/env bash

# Author: Jon Schipp

########
# Examples:

# 1.) Check system load with autodetect OS and CPU's to determine thresholds
# $ ./check_load.sh -a

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Check system load for Linux, FreeBSD, OSX, and AIX.

     Options:

	-a		Autodetect OS and CPUs
	-c <int> 	Critical threshold
	-o <os>		OS type, "linux/osx/freebsd/aix"
	-p <int>	Specify number of CPUs
	-w <int>	Warning threshold

Usage:$0 -a
EOF
}

argcheck() {
# if less than n argument
if [ $ARGC -lt $1 ]; then
	echo "Missing arguments! Use \`\`-h'' for help."
	exit 1
fi
}

determine_cpus() {

if [[ $OS == linux ]]; then
	CORES=$(nproc)
fi

if [[ $OS == freebsd ]]; then
	CORES=$(sysctl -n hw.ncpu)
fi

if [[ $OS == osx ]]; then
	CORES=$(sysctl -n hw.ncpu)
fi

if [[ $OS == aix ]]; then
	CORES=$(lparstat -i | awk -F : '/Active Physical CPUs/ { print $2 }')
fi
}

determine_command () {

if [[ "$OS" == osx ]]; then
	UPTIME=$(uptime | awk -F : '{ print $4 }')
elif [[ "$OS" == linux ]]; then
	UPTIME=$(uptime |sed 's/.*: //' | sed 's/,//g')
elif [[ "$OS" == freebsd ]]; then
	UPTIME=$(uptime | awk -F : '{ print $4 }' | sed 's/,//g')
elif [[ "$OS" == aix ]]; then
	UPTIME=$(uptime | awk -F : '{ print $4 }' | sed 's/,//g')
else
	echo "OS not supported"
	exit $UNKNOWN
fi
}
auto_os_detect() {

UNAME=$(uname)

 if [[ "$UNAME" == Linux ]]; then
        OS="linux"
 elif [[ "$UNAME" == Darwin ]]; then
        OS="osx"
 elif [[ "$UNAME" == Freebsd ]]; then
        OS="freebsd"
 elif [[ "$UNAME" == AIX ]]; then
        OS="aix"
 else
        echo "Unsupported OS type!"
        exit 1
 fi

}

ARGC=$#
CRIT=0
WARN=0
THRESHOLD=0
LOAD=0
AUTO_DETECT=0
CORES=0
OS=null
CRIT_STATUS=0
WARN_STATUS=0
OK_STATUS=0

argcheck 1

while getopts "hac:o:p:w:" OPTION
do
     case $OPTION in
         h)
             usage
	     exit 0
             ;;
	 a)
	     AUTO_DETECT=1
	     auto_os_detect
	     determine_cpus
	     ;;
	 c)
	     CRIT="$OPTARG"
	     THRESHOLD=1
             ;;
	 o)
	     echo "Need to implement \`\`-o'' yet"
	     exit 1
	     ;;
	 p)
	     CORES="$OPTARG"
	     ;;
	 w)
	     WARN="$OPTARG"
	     THRESHOLD=1
	     ;;
         \?)
             exit 1
             ;;
     esac
done

determine_command

if [ $THRESHOLD -eq 0 ]; then

	for load in $UPTIME
	do
        LOAD=$(/usr/bin/printf "%f\n" $load 2>/dev/null)

		if [ $LOAD -gt $CORES ]; then
			CRIT_STATUS=$((CRIT_STATUS+1))
		elif [ $LOAD -gt $CORES ]; then
			WARN_STATUS=$((WARN_STATUS+1))
		else
			OK_STATUS=$((OK_STATUS+1))
		fi
	done

fi

if [ $THRESHOLD -eq 1 ]; then

	for load in $UPTIME
	do
        LOAD=$(/usr/bin/printf "%f\n" $load 2>/dev/null)

        if [ $(echo "$LOAD > $CRIT" | bc) -eq 1 ]; then
			CRIT_STATUS=$((CRIT_STATUS+1))
        elif [ $(echo "$LOAD > $WARN" | bc) -eq 1 ]; then
			WARN_STATUS=$((WARN_STATUS+1))
		else
			OK_STATUS=$((OK_STATUS+1))
		fi
	done
fi

if [ $CRIT_STATUS -gt 0 ]; then
	echo "Load average critical: $UPTIME"
	exit $CRITICAL
elif [ $WARN_STATUS -gt 0 ]; then
	echo "Load average warning: $UPTIME"
	exit $WARNING
else
	echo "Load average: $UPTIME"
	exit $OK
fi
