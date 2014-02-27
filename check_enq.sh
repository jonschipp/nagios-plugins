#!/usr/bin/env bash

# Author: Jon Schipp

########
# Examples:

# 1.) Return critical if any queue is in the DOWN state
# $ ./check_enq.sh -d
#
# 2.) Return critical if any queue is in the DOWN state except those listed
# $ ./check_enq.sh -d -e "color,black,invoice"
#
# 3.) Return critical if color is in DOWN state
# $ ./check_enq.sh -d -q color

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# set default values for the thresholds
usage()
{
cat <<EOF

Check printer queue status (enq) on AIX. If the queue
matches the given status then return OK.

     Options:
     -q		Comma separated list of print queue names (def: all)
     -d 	Given a queue, alert on those in a DOWN state
     -e		Comma separated list of queues to exclude from the default all list
     -s		Status to look for (READY/RUNNING/DOWN/QUEUED)

Usage: $0 -q "invoice,black" -s READY
EOF
}

argcheck() {
# if less than n argument
if [ $ARGC -lt $1 ]; then
        echo "Missing arguments! Use \`\`-h'' for help."
        exit 1
fi
}

ARGC=$#
DOWN_CHECK=0
STATUS_CHECK=0
QUEUE=".*"
WONTMATCH=asdlfjasdlfjasdflasdjfaldsjfaldfj

argcheck 1

while getopts "hde:q:s:" ARG;
do
        case $ARG in
		d) DOWN_CHECK=1
                   ;;
		e) EXCLUDE=$(echo $OPTARG| sed 's/,/|/')
	           ;;
		q) QUEUE=$(echo $OPTARG| sed 's/,/|/')
                   ;;
                s) STATUS=$OPTARG
		   STATUS_CHECK=1
                   ;;
                h) usage
                   exit
                   ;;
        esac
done

if [ $DOWN_CHECK -eq 1 ]; then
	enq -A all | grep -v -E "${EXCLUDE:-$WONTMATCH}" | grep -E "$QUEUE" | grep DOWN && exit $CRITICAL ||
		(echo "No queues in down state" && exit $OK)
fi

#if [ $STATUS_CHECK -eq 1 ]; then
#	enq -A all |
#fi
