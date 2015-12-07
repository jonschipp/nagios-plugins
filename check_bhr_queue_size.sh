#!/usr/bin/env bash

# Nagios plugin to check the BHR queue size

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# set default values for the thresholds
WARN=10
CRIT=50

QDIR="/var/lib/bhrqueue"

entries=$(find $QDIR -type f | fgrep -v .lck | wc -l)

if [ $entries -gt $CRIT ]; then
        echo "CRITICAL: $entries"
        exit $CRITICAL;
elif [ $entries -gt $WARN ]; then
        echo "WARNING: $entries"
        exit $WARNING;
else
        echo "OK: $entries"
        exit $OK;
fi
