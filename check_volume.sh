#!/usr/bin/env bash

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Check the capacity of a volume using df.

     Options:
        -v         Specify volume as mountpoint
        -c         Critical threshold as an int (0-100)
        -w         Warning threshold as an int (0-100)
	-s 	   Skip threshold checks

Usage: $0 -v /mnt -c 95 -w 90
EOF
}

if [ $# -lt 6 ]; 
then
	usage
	exit 1
fi

# Define now to prevent expected number errors
VOL=/dev/da0
CRIT=0
WARN=0
SKIP=0
OS=$(uname)

while getopts "hc:sv:w:" OPTION
do
     case $OPTION in
         h)
	     usage
             ;;
         c)
	     CRIT="$OPTARG"
             ;;
	 s)
	     SKIP=1
	     ;;
         v)
             VOL="$OPTARG"
             ;;
	 w) 
	     WARN="$OPTARG"
	     ;;
         \?)
             exit 1
             ;;
     esac
done

if [[ $OS == AIX ]]; then
	STATUS=$(df "$VOL" | awk '!/Filesystem/ { print $4 }' | sed 's/%//')
	SIZE=$(df -P -m "$VOL" | awk '!/Filesystem/ { print $4 }')
	USED=$(df -P -m "$VOL" | awk '!/Filesystem/ { print $3 }')
else
	STATUS=$(df -h "$VOL" | awk '!/Filesystem/ { print $5 }' | sed 's/%//')
	SIZE=$(df -h "$VOL" | awk '!/Filesystem/ { print $2 }')
	USED=$(df -h "$VOL" | awk '!/Filesystem/ { print $3 }')
fi

if [ $SKIP -eq 1 ]; then
        echo "$VOL is at ${STATUS}% capacity, $USED of $SIZE (Threshold skipped)"
        exit $OK
fi

if [ $STATUS -gt $CRIT ]; then
        echo "$VOL is at ${STATUS}% capacity! $USED of $SIZE"
        exit $CRITICAL
elif [ $STATUS -gt $WARN ]; then
        echo "$VOL is at ${STATUS}% capacity! $USED of $SIZE"
        exit $WARNING
else
        echo "$VOL is at ${STATUS}% capacity, $USED of $SIZE"
        exit $OK
fi 
