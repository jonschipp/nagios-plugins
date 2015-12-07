#!/usr/bin/env bash

# Author: Jon Schipp
# Date: 04-15-2014
########
# Examples:

# 1.) Check if sshd has restarted since last check
# $ ./check_pid.sh -f /var/run/sshd.pid

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Check if a service has been restarted by comparing its PID to each previous run.

  Options:
    -f       Specify PID filename as full path
    -o	     Temporary PID file storage directory (def: /tmp)

Usage: $0 -f /var/run/sshd.pid -o /tmp/pids/
EOF
}

if [ $# -lt 1 ];
then
  usage
  exit 1
fi

# Define now to prevent expected number errors
DIR=/tmp
CHECK=0
COUNT=0

while getopts "hf:o:" OPTION
do
  case $OPTION in
    h)
      usage
      ;;
    f)
      FILEPATH="$OPTARG"
      CHECK=1
      ;;
    o)
      DIR="$OPTARG"
      ;;
    \?)
      exit 1
      ;;
  esac
done

FILE=$(echo $FILEPATH | sed 's/^.*\///')

if [ ! -f $FILEPATH ]; then
  echo "File doesn't exist or is not a regular file!"
  exit $UNKNOWN
fi

if [ $CHECK -eq 1 ]; then
  if [ ! -f $DIR/$FILE ]; then
    echo "First run for PID or can't access file in temporary storage location: $DIR/$FILE"
    cp -f $FILEPATH $DIR
    exit $UNKNOWN
  fi

  # In case the PID is temporarily locked by another program
  until [ ! -z $NEWPID ] && [ ! -z $OLDPID ];
  do
    NEWPID=$(cat $FILEPATH)
    OLDPID=$(cat $DIR/$FILE)
    COUNT=$((COUNT+1))
    if [ $COUNT -ge 10 ]
    then
            break
    fi
  done

  if [ $NEWPID -eq $OLDPID ]; then
    echo "Service is still running with the same PID: $(echo $NEWPID)"
    cp -f $FILEPATH $DIR
    exit $OK
  else
    echo "Service restarted. OLDPID: $(echo $OLDPID) NEWPID: $(echo $NEWPID)"
    cp -f $FILEPATH $DIR
    exit $CRITICAL
  fi
fi
