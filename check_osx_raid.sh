#!/usr/bin/env bash

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Check the RAID status for disks on OSX.

     Options:
       -l 	      List full RAID information
       -c	      Check RAID status

Usage: $0 -c
EOF
}

argcheck() {
# if less than n argument
if [ $ARGC -lt $1 ]; then
        echo "Missing arguments! Use \`\`-h'' for help."
        exit 1
fi
}

RAID_CHECK=0
ARGC=$#

argcheck 1

while getopts "hlc" OPTION
do
     case $OPTION in
         h)
	     usage
             ;;
	 c)
	     RAID_CHECK=1
	     ;;
	 l) 
	     diskutil appleRAID list
	     exit $OK
	     ;;
         \?)
             exit $UNKNOWN
             ;;
     esac
done

if [ $RAID_CHECK -eq 1 ]; then

STATUS_ROW=$(diskutil appleRAID list | awk '/^Status:/ { print $2 }')
DISK=$(diskutil appleRAID list | awk '/disk.*(Fail|ebuild)/ { print $2 }')
STATUS=$(diskutil appleRAID list | grep ^[0-9])

case $STATUS in

*[fF]ailed*)
	echo "$DISK Failure: $STATUS_ROW array!"
	exit $CRITICAL
	;;
*[oO]ffline*)
	echo "$DISK Failure: $STATUS_ROW array!"
	exit $CRITICAL
	;;
*[dD]egraded*)
	echo "$DISK Failure: $STATUS_ROW array!"
	exit $CRITICAL
	;;
*[Rr]ebuilding*)
	echo "$DISK Rebuilding: $STATUS_ROW array!"
	exit $WARNING
	;;
*[oO]nline*)
	echo "RAID array is online."
	exit $OK
	;;
*)	
	echo "Unknown status for: $STATUS"
	exit $UNKNOWN	
	;;
esac

fi
