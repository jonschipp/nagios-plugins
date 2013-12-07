#!/usr/bin/env bash

# Author: Jon Schipp
# Date: 11-07-2013
########
# Examples:

# 1.) Check if file has grown in the last 30 seconds
# $ ./check_file_growth.sh -f /var/log/system.log -M stat -i 30
#  File grew by 118 bytes
#
# 2.) If file has grown by more than (c)ritical or (w)arning bytes in 30 seconds exit with critical or warning status
# $ ./check_file_growth -f big.log -M stat -T bigger -c 1000000 -w 5000000 -i 30

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Check the level of byte growth of a file for a time interval.
Also, check that a file is growing.

     Options:
        -f           Specify filename as full path
	-i <int>     Interval in seconds
	-M <command> Command to use for the checks
	       	     "wc/stat" wc is portable but slower, stat is faster but less portable
	-T <type>    Type of concern for thresholds
		     "bigger/smaller" than thresholds
        -c <int>     Critical threshold in bytes
        -w <int>     Warning threshold in bytes

Usage: $0 -f big.log -M stat -T bigger -c 1000000 -w 5000000 -i 30
EOF
}

if [ $# -lt 4 ]; 
then
	usage
	exit 1
fi

# Define now to prevent expected number errors
FILE=/dev/null
TYPE=bigger
CONCERN=0
TIME=0
CRIT=0
WARN=0
NEW=0
OLD=0
GROWTH=0
PROG=wc
OS=$(uname)

while getopts "hc:f:i:M:T:w:" OPTION
do
     case $OPTION in
         h)
	     usage
             ;;
         c)
	     CRIT="$OPTARG"
             ;;
	 f)
	     FILE="$OPTARG"
	     ;;
	 i) 
	     TIME="$OPTARG"
	     ;;
	 M)
	     PROG="$OPTARG"
	     if [[ "$OPTARG" == stat ]]; then
            	PROG="$OPTARG"
             elif [[ "$OPTARG" == wc ]]; then
             	PROG="$OPTARG"
             else
             	echo "Unknown argument to \`\`-M''! Choose wc or stat."
             	exit 1
	     fi
	     ;;
         v)
             FILE="$OPTARG"
             ;;
	 T)
	     CONCERN=1
	     if [[ "$OPTARG" == bigger ]]; then
            	TYPE="$OPTARG"
             elif [[ "$OPTARG" == smaller ]]; then
             	TYPE="$OPTARG"
             else
             	echo "Unknown type!"
             	exit 1
             fi
	     ;;
	 w) 
	     WARN="$OPTARG"
	     ;;
         \?)
             exit 1
             ;;
     esac
done

if [ ! -f $FILE ]; then
	echo "File doesn't exist or is not a regular file!"
	exit $UNKNOWN
fi

if [ $PROG == stat ] && [[ $OS != AIX ]]; then

	if [[ $OS == Linux ]]; then
		OLD=$(stat -c %s $FILE)
		sleep $TIME
		NEW=$(stat -c %s $FILE)
	else
		OLD=$(stat -f %z $FILE)
		sleep $TIME
		NEW=$(stat -f %z $FILE)
	fi
else
	OLD=$(wc -c $FILE | awk '{ print $1}')
	sleep $TIME
	NEW=$(wc -c $FILE | awk '{ print $1}')
fi

GROWTH=$(($NEW-$OLD))

if [ $CONCERN -eq 0 ]; then 

	if [ $GROWTH -gt 0 ]; then
		echo "File grew by $GROWTH bytes"
		exit $OK
	else
		echo "File hasn't grown"
		exit $CRITICAL
	fi

fi

if [ $CONCERN -eq 1 ]; then

	if [ $TYPE == "bigger" ]; then

		if [ $GROWTH -ge $CRIT ]; then
			echo "File grew by $GROWTH bytes in ${TIME} seconds"
			exit $CRITICAL
		elif [ $GROWTH -ge $WARN ]; then
			echo "File grew by $GROWTH bytes in ${TIME} seconds"
			exit $WARNING
		else
			echo "File grew by $GROWTH bytes in ${TIME} seconds"
			exit $OK
		fi   
	fi

	if [ $TYPE == "smaller" ]; then

		if [ $GROWTH -le $CRIT ]; then
			echo "File grew by $GROWTH bytes in ${TIME} seconds"
			exit $CRITICAL
		elif [ $GROWTH -le $WARN ]; then
			echo "File grew by $GROWTH bytes in ${TIME} seconds"
			exit $WARNING
		else
			echo "File grew by $GROWTH bytes in ${TIME} seconds"
			exit $OK
		fi
	fi
fi
