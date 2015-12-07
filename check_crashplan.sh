#!/usr/bin/env bash

# Author: Jon Schipp

########
# Examples:

# 1.) Check if Crashplan is installed
# $ ./check_crashplan.sh -I

# 2.) Check Java heap settings of crashplan
# $ ./check_crashplan.sh -H

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Default Location of the binaries
# Set these to the proper location if your installation differs
CP_BIN=/usr/local/crashplan/bin/CrashPlanEngine
CP_CONF=/usr/local/crashplan/bin/run.conf

usage()
{
cat <<EOF

Check status of CrashPlan on GNU/Linux

     Options:
        -I              Check if Crashplan is installed and running
        -H              Check if Crashplan heap size is >= Xmx4096m

Usage: $0 -H
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
CHECK_INSTALLED=0
CHECK_CONF=0
ARGC=$#

argcheck 1

while getopts "hIH" OPTION
do
     case $OPTION in
         h)
             usage
             ;;
         I)
             CHECK_INSTALLED=1
             ;;
         H)
             CHECK_CONF=1
             ;;
         \?)
             exit 1
             ;;
     esac
done

if [[ $CHECK_INSTALLED -eq 1 ]]; then
  [[ -x $CP_BIN ]] || { echo "$CP_BIN not installed or executable" && exit $OK; }
  status=$(service crashplan status 2>&1)
  echo $status | egrep -q 'running|started' || { echo "$CP_BIN is installed but not running: ${status}" && exit $CRITICAL; }
  echo "$CP_BIN is installed and running" && exit $OK
fi

if [[ $CHECK_CONF -eq 1 ]]; then
  [[ -r $CP_CONF ]] || { echo "$CP_CONF not found or readable" && exit $OK; }
  . $CP_CONF
  echo $SRV_JAVA_OPTS | grep -q "Xmx[4-9][0-9][0-9][0-9][mM]" || { echo "Java heap too small: $SRV_JAVA_OPTS" && exit $CRITICAL; }
  echo "Heap is okay" && exit $OK
fi
