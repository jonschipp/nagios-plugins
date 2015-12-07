#!/usr/bin/env bash

# Author: Jon Schipp
# Date: 09-10-2014
########
# Examples:

# 1.) Check if sshd has restarted since last check
# $ ./check_fs_write.sh -o /var,/tmp

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Notify if a filesystem is read-only by writing a file to it.

     Options:
        -f           Specify custom filename (optional)
	-o	     Specify destinations to write, comma separated

Usage: $0 -o /var,/home,/tmp,/nfs
EOF
}

if [ $# -lt 1 ];
then
	usage
	exit 1
fi

# Define now to prevent expected number errors
CHECK=0
CRIT=0
FILE=68b329da9893e34099c7d8ad5cb9c940

while getopts "hf:o:" OPTION
do
     case $OPTION in
         h)
	     usage
             ;;
	 f)
	     FILE="$OPTARG"
	     ;;
	 o)
	     DIR=$(echo "$OPTARG" | sed 's/,/ /g');
	     CHECK=1
	     ;;
         \?)
             exit 1
             ;;
     esac
done

if [ $CHECK -eq 1 ]; then

	for directory in $DIR
	do
		timeout 3s touch $directory/$FILE 2>/dev/null
		if [ $? -ne 0 ]; then
			echo "Failure to write file to ${directory}!"
			CRIT=1
		else
			rm -f $directory/$FILE
			echo "Success writing file to $directory"
		fi
	done

	if [ $CRIT -eq 1 ]; then
		echo "State: CRITICAL"
		exit $CRITICAL
	else
		echo "State: OK"
		exit $OK
	fi

fi
