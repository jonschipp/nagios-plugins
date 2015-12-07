#!/usr/bin/env bash
# Author: Jon Schipp
# Date: 01-27-2014
########
# Examples:

# 1.) Check presence of disk queue (buffer)
# $ ./check_sagan.sh -T  -q rsyslog -d /var/spool/rsyslog

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Default rsyslog spool directory
FILE=/var/log/sagan/sagan.stats
usage()
{
cat <<EOF

Checks most recent sagan stats preprocessor line for specified thresholds

     Options:
	-c <int>	 Critical number
	-w <int>	 Warning number
	-f <file>	 Set file when using impstats checks
	-T <type>	 Check type (total/dropped/ignored/signatures)
				total   - Check total processed messages
				drop - Check dropped messages
				ignore - Check gnore matches
				signature - Check signature matches

Usage: $0 -T dropped
EOF
}

compare(){
local msg=$1
local count=$2

if [[ $count -gt $CRIT ]]; then
  echo "CRITICAL: $count $msg"
  exit $CRITICAL;
elif [[ $count -gt $WARN ]]; then
  echo "WARNING: $count $msg"
  exit $WARNING;
else
  echo "OK: $count $msg"
  exit $OK;
fi
}

argcheck(){
# if less than n argument
if [ $ARGC -lt $1 ]; then
        echo "Missing arguments! Use \`\`-h'' for help."
        exit 1
fi
}

# Initialize variables
ARGC=$#
TOTAL_CHECK=0
DROP_CHECK=0
IGNORE_CHECK=0
SIG_CHECK=0
CRIT=0
WARN=0

argcheck 1

while getopts "hc:w:f:T:" OPTION
do
     case $OPTION in
         h) usage ;;
	 c) CRIT=$OPTARG ;;
	 w) WARN=$OPTARG ;;
         f)
	   if [[ -r $OPTARG ]]; then
             FILE="$OPTARG"
	   else
	     echo "Does $OPTARG exist and is readable?"
	     exit $UNKNOWN
	   fi
	   ;;
	 T)
           if [[ "$OPTARG" == "total" ]]; then
             TOTAL_CHECK=1
	   elif [[ "$OPTARG" == "drop" ]]; then
             DROP_CHECK=1
	   elif [[ "$OPTARG" == "ignore" ]]; then
             IGNORE_CHECK=1
	   elif [[ "$OPTARG" == "signature" ]]; then
             SIG_CHECK=1
	   else
             echo "$OPTARG is not a valid check type"
             exit $WARNING
	   fi
	   ;;
         \?)
           exit $WARNING ;;
     esac
done

stats_line=$(tail -n 1 $FILE) || { echo "Not able to read $FILE" && exit $UNKNOWN; }
[[ $stats_line  =~ ^# ]] && echo "Waiting for stats.." && exit $OK

[[ $TOTAL_CHECK -eq 1 ]]  && count=$(echo $stats_line | cut -d , -f2) && compare total $count
[[ $ISG_CHECK -eq 1 ]]    && count=$(echo $stats_line | cut -d , -f3) && compare signature $count
[[ $DROP_CHECK -eq 1 ]]   && count=$(echo $stats_line | cut -d , -f7) && compare dropped $count
[[ $IGNORE_CHECK -eq 1 ]] && count=$(echo $stats_line | cut -d , -f8) && compare ignored $count
