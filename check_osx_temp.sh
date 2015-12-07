#!/usr/bin/env bash

# Monitor temperatures in OSX
# Depends on the installation of TemperatureMonitor from www.bresink.com/osx/TemperatureMonitor.html

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Check the temperature sensors on OSX

     Options:
       -t	Monitor tempatures
       -c	Critical threshold in Fahrenheit

Usage: $0 -t -c 180
EOF
}

argcheck() {
# if less than n argument
if [ $ARGC -lt $1 ]; then
        echo "Missing arguments! Use \`\`-h'' for help."
        exit 1
fi
}

MONITOR=0
CRIT=0
WARN=0
COMMAND="/Applications/TemperatureMonitor.app/Contents/MacOS/tempmonitor -ds -f -a -l"
ARGC=$#

argcheck 1

if ! [ -f /Applications/TemperatureMonitor.app/Contents/MacOS/tempmonitor ]; then
	echo "tempmonitor not found. Install package from www.bresink.com/osx/TemperatureMonitor.html"
	exit $UNKNOWN
fi

while getopts "htc:" OPTION
do
     case $OPTION in
         h)
	     usage
             ;;
	 t)
	     MONITOR=1
	     ;;
	 c)
	     CRIT="$OPTARG"
	     ;;
	 w)
	     WARN="$OPTARG"
	     ;;
         \?)
             exit 1
             ;;
     esac
done

if [ $MONITOR -eq 1 ]; then
	$COMMAND | sed 's/ F//' | awk -v crit=$CRIT -F : \
	'$2 > crit { high=1; print $0 }
	END {
	if (high == 1) {
		exit 2
	} else {
		exit 0
		}
	}'

	if [ $? -eq 2 ]; then
		exit $CRITICAL
	else
		echo "No high temperatures"
		exit $OK
	fi
fi
