#!/usr/bin/env bash

# Author: Jon Schipp
# Date: 01-27-2014
########
# Examples:

# 1.) Check presence of disk queue (buffer)
# $ ./check_rsyslog.sh -q rsyslog -d /var/spool/rsyslog

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Default rsyslog spool directory 
WORK_DIRECTORY=/var/spool/rsyslog

usage()
{
cat <<EOF

     Options:
        -q <basename>    Check for presence of disk queue files
	-d <dir>	 Specify \$WorkDirectory (def: /var/spool/rsyslog)

Usage: $0 -q buf
EOF
}

argcheck() {
# if less than n argument
if [ $ARGC -lt $1 ]; then
        echo "Missing arguments! Use \`\`-h'' for help."
        exit 1
fi
}

# Initialize variables
ARGC=$#
QUEUE_CHECK=0

argcheck 1

while getopts "hd:q:" OPTION
do
     case $OPTION in
         h)
             usage
             ;;
	 d)
	     WORK_DIRECTORY=$(echo $OPTARG | sed 's/\/$//')
	     ;;
         q)
             BASENAME=$OPTARG
	     QUEUE_CHECK=1
             ;;
         \?)
             exit 1
             ;;
     esac
done

if [ $QUEUE_CHECK -eq 1 ]; then

	# Remove stale 0 byte queue files
	# find $WORK_DIRECTORY -type f -size 0c -regextype posix-basic -regex ".*/$BASENAME.*\.[0-9]\{8\}" | xargs rm -rf

	COUNT=$(find $WORK_DIRECTORY -type f -size +0c -regextype posix-basic -regex ".*/$BASENAME.*\.[0-9]\{8\}" | wc -l)

	if [ $COUNT -gt 0 ]; then
		echo "Found buffer files"
		find $WORK_DIRECTORY -type f -size +0c -regextype posix-basic -regex ".*/$BASENAME.*\.[0-9]\{8\}"
		exit $CRITICAL
	else
		echo "No buffer files found"
		exit $OK
	fi
fi
