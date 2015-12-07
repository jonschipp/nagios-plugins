#!/usr/bin/env bash
# awk '{ for( i=NF; i>=1; i--) print $i }'
# Author: Jon Schipp
# Date: 01-27-2014
########
# Examples:

# 1.) Check presence of disk queue (buffer)
# $ ./check_rsyslog.sh -T buffer -q rsyslog -d /var/spool/rsyslog

# 1.) Check number of logs currently in the queue
# $ ./check_rsyslog.sh -T queued -f /var/log/impstats.log -c 100

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
	-c <int>	 Critical number
	-w <int>	 Warning number
        -q <basename>    Check for presence of disk queue files (use with \`\`-T buffer'')
	-d <dir>	 Specify \$WorkDirectory (def: /var/spool/rsyslog) (use with \`\`-T buffer)
	-f <file>	 Set file when using impstats checks
	-T <type>	 Check type (buffer/queued)
				buffer - Check for presence of buffer files
				queued - Check impstats log file for number of queued logs

Usage: $0 -S buffer -q buf
EOF
}

compare () {
COUNT=$1
if [ $COUNT -gt $CRIT ]; then
        echo "CRITICAL: $BASENAME: $COUNT queued messages"
        exit $CRITICAL;
elif [ $COUNT -gt $WARN ]; then
        echo "WARNING: $BASENAME: $COUNT queued messages"
        exit $WARNING;
else
        echo "OK: $BASENAME: $COUNT queued messages"
        exit $OK;
fi
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
QUEUED_STATS_CHECK=0
FILE=0
CRIT=0
WARN=0

argcheck 1

while getopts "hc:w:f:d:q:T:" OPTION
do
     case $OPTION in
         h) usage ;;
	 c) CRIT=$OPTARG ;;
	 w) WARN=$OPTARG ;;
	 d)
	     WORK_DIRECTORY=$(echo $OPTARG | sed 's/\/$//')
	     ;;
         f)
	     if [ -f $OPTARG ]; then
	     	FILENAME="$OPTARG"
		FILE=1
	     else
		echo "Does $OPTARG exist and is a regular file?"
		exit $WARNING
	     fi
	     ;;
         q)
             BASENAME=$OPTARG
             ;;
	 T)
             if [[ "$OPTARG" == "queued" ]]; then
                        QUEUED_STATS_CHECK=1
	     elif [[ "$OPTARG" == "buffer" ]]; then
			QUEUE_CHECK=1
	     else
			echo "$OPTARG is not a valid check type"
			exit $WARNING
	     fi
	     ;;
         \?)
             exit $WARNING ;;
     esac
done

if [ $QUEUE_CHECK -eq 1 ]; then

	# Remove stale 0 byte queue files
	# find $WORK_DIRECTORY -type f -size 0c -regextype posix-basic -regex ".*/$BASENAME.*\.[0-9]\{8\}" | xargs rm -rf

	COUNT=$(find $WORK_DIRECTORY -type f -size +0c -regextype posix-basic -regex ".*/$BASENAME.*\.[0-9]\{7\}[2-9]" | wc -l)

	if [ $COUNT -gt 0 ]; then
		echo "Found buffer files"
		find $WORK_DIRECTORY -type f -size +0c -regextype posix-basic -regex ".*/$BASENAME.*\.[0-9]\{7\}[2-9]"
		exit $CRITICAL
	else
		echo "No buffer files found"
		exit $OK
	fi
fi

if [ $QUEUED_STATS_CHECK -eq 1 ] && [ $FILE -eq 1 ]; then

	RESULT=$(awk "/$BASENAME/ && /$(date +"%b %e")/" $FILENAME | \
            grep -o ' size=[0-9]\+ ' | tail -1 | awk -F = '{ print $2 }')

	compare $RESULT
fi
