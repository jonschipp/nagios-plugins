#!/usr/bin/env bash

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Check the S.M.A.R.T status for a disk on OSX.

     Options:
       -d <disk>      Specify volume a disk
       -l 	      List available disks

Usage: $0 -d disk0
EOF
}

argcheck() {
# if less than n argument
if [ $ARGC -lt $1 ]; then
        echo "Missing arguments! Use \`\`-h'' for help."
        exit 1
fi
}

CHECK=0
ARGC=$#

argcheck 1

while getopts "hld:" OPTION
do
     case $OPTION in
         h)
	     usage
             ;;
	 l)
	     diskutil list
	     exit 0
	     ;;
	 d)
	     CHECK=1
	     DISK="$OPTARG"
	     ;;
         \?)
             exit 1
             ;;
     esac
done

if [ $CHECK -eq 1 ]; then

	if [ -b /dev/${DISK} ]; then
		STATUS=$(diskutil info $DISK | awk '/SMART/ { print $3 }')
	else
		echo "$DISK is not a valid block device"
	exit 3
	fi

	case $STATUS in

	[vV]erified)
		echo "Disk $DISK is OK."
		exit $OK
		;;
	*[nN]ot*)
		echo "SMART status is not supported for this disk (e.g. externals): $DISK"
		exit $OK
		;;
	*[fF]ail*)
		echo "Disk $DISK is failing."
		exit $CRITICAL
		;;
	*)
		echo "Unknown status for $DISK: $STATUS"
		exit $UNKNOWN
		;;
	esac

fi
