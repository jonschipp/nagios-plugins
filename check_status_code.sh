#!/usr/bin/env bash

# Author: Jon Schipp

########
# Examples:

# 1.) Check status code for uptime using the defaults
# $ ./check_status_code.sh -r /usr/bin/uptime
#
# 2.) Custom service does it backwards and exits 1 when running and 0 when stopped.
# $ ./check_status_code.sh -r "/usr/sbin/service custom-server status" -o 1 -c 0

# Nagios Exit Codes
NAGIOS_OK=0
NAGIOS_WARNING=1
NAGIOS_CRITICAL=2
NAGIOS_UNKNOWN=3

# Mutable Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Checks the status, or exit, code of another program and returns a
Nagios status code based on the result.

     Options:
        -r <cmd>    Absolute path of program to run, use quotes for options
        -o <int>    Status to expect for OK state       (def: 0)
        -w <int>    Status to expect for WARNING state  (def: 1)
        -c <int>    Status to expect for CRITICAL state (def: 2)
        -u <int>    Status to expect for UNKNOWN state  (def: 3)

Usage: $0 -r "/usr/sbin/service sshd status"
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

argcheck 1

while getopts "hc:o:r:w:u:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 0
             ;;
         r)  if ! [ -z $RUN ]; then
		     echo "Error: Argument \`\`-r'' is required''."
		     exit 1
	     else
		     RUN="$OPTARG"
	     fi
             ;;
         o)
             OK=$OPTARG
             ;;
         w)
	     WARNING=$OPTARG
             ;;
         c)
	     CRITICAL=$OPTARG
             ;;
         u)
	     UNKNOWN=$OPTARG
             ;;
         \?)
             exit 1
             ;;
     esac
done

COMMAND=$(echo $RUN | sed 's/ .*//')

if ! [ -x $COMMAND ]; then
	echo "Error: $COMMAND does not exist, is not an absolute path,  or is not executable."
	exit 1
fi

$RUN

CODE=$?

if [ $CODE -eq $OK ]; then
	exit $NAGIOS_OK
elif [ $CODE -eq $WARNING ]; then
	exit $NAGIOS_WARNING
elif [ $CODE -eq $CRITICAL ]; then
	exit $CRITICAL
elif [ $CODE -eq $UNKNOWN ]; then
	exit $NAGIOS_UNKNOWN
else
	echo "Exit code not understood: $CODE"
fi
