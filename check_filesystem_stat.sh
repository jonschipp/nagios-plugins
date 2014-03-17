#!/usr/bin/env bash

# Author: Jon Schipp

########
# Examples:

# 1.) Return critical if stat does not exit successfully
# $ ./check_filesystem_errors.sh -p /mnt -d 2
#

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Nagios plug-in that recursively checks for filesystem input/output
errors by directory using stat.

      Options:

      -p <dir> 	Directory or mountpoint to begin
      -d <int>	Depth i.e. level of subdirectories to check (def: 1)

EOF
}

argcheck() {
if [ $ARGC -lt $1 ]; then
	echo "Please specify an argument!, try $0 -h for more information"
        exit 1
fi
}

DEPTH=1
CHECK=0
COUNT=0
ARGC=$#

# Print warning and exit if less than n arguments specified
argcheck 1

# option and argument handling
while getopts "hp:d:" OPTION
do
     case $OPTION in
         h)
             usage
             exit $UNKNOWN
             ;;
         p)
	     CHECK=1
	     DIR=$OPTARG
	     ;;
	 d)
	     DEPTH=$OPTARG
	     ;;
	 *)
	     exit $UNKNOWN
             ;;
     esac
done

if [ $CHECK -eq 1 ]; then

	find $DIR -maxdepth $DEPTH -type d -print0 | xargs -0 -I file sh -c 'stat "file" 1>/dev/null 2>/dev/null || (echo "Error file" && exit 2)'

	if  [ $? -gt 0 ]; then
		echo "CRITICAL: Found filesystem errors"
		exit $CRITICAL
	else
		echo "OK: No filesystem errors found"
		exit $OK
	fi

fi
