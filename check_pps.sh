#!/usr/bin/env bash

# Author: Jon Schipp

########
# Examples:

# 1.) Return critical if there's more than 10k PPS
# $ ./check_pps.sh -i eth0 -w 8000 -c 10000  -p
#
# 2.) Return critical if there's more than 1m BPS
# $ ./check_pps.sh -i eth0 -w 500000 -c 1000000 -b
#
# 2.) Return critical if we've reach 70% of the NIC's line-rate capacity
# $ ./check_pps.sh -i eth0 -w 50 -c 70 -r
#

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Nagios plug-in that calculates receiving PPS, BPS, and percentage of line-rate (LR)
from Linux kernel statistics by reading from procfs and reports if above a given threshold.

      Options:

      -i 		Network interface
      -p 		Use PPS as criteria
      -b		Use BPS as criteria
      -r		Use percentage of line-rate as criteria
      -t <int>		Time interval in seconds (def: 1)
      -w <int>		Warning threshold
      -c <int>		Critical threshold

EOF
}

argcheck() {
if [ $ARGC -lt $1 ]; then
	echo "Please specify an argument!, try $0 -h for more information"
        exit 1
fi
}

get_network_data() {

		# Get speed of NIC
		speed=$(cat /sys/class/net/$INT/speed)

		# Get number of packets for interface
		rxppsold=$(awk "/$INT/ "'{ sub(":", " "); print $3 }' /proc/net/dev)
		txppsold=$(awk "/$INT/ "'{ sub(":", " "); print $11 }' /proc/net/dev)

		# Get number of bytes for interface
		rxbytesold=$(awk "/$INT/ "'{ sub(":", " "); print $2 }' /proc/net/dev)
		txbytesold=$(awk "/$INT/ "'{ sub(":", " "); print $10 }' /proc/net/dev)

		sleep $INTERVAL

		# Get number of packets for interface again and subtract from old
		rxppsnew=$(awk -v rxppsold="$rxppsold" "/$INT/ "'{ \
			sub(":", " "); rxppsnew = $3; print rxppsnew - rxppsold }' /proc/net/dev)
		txppsnew=$(awk -v txppsold="$txppsold" "/$INT/ "'{ \
			sub(":", " "); txppsnew = $11; print txppsnew - txppsold }' /proc/net/dev)

		# Get number of bytes for interface again and subtract from old
		rxbytesnew=$(awk -v rxbytesold="$rxbytesold" "/$INT/ "'{ \
			sub(":", " "); rxbytesnew = $2; print rxbytesnew - rxbytesold }' /proc/net/dev)
		txbytesnew=$(awk -v txbytesold="$txbytesold" "/$INT/ "'{ \
			sub(":", " "); txbytesnew = $10; print txbytesnew - txbytesold }' /proc/net/dev)

		# Calculate percentage of line-rate from number of bytes per second.
		rxlinerate=$(echo "$rxbytesnew / 125000 / $speed * 100" | bc -l)
		txlinerate=$(echo "$txbytesnew / 125000 / $speed * 100" | bc -l)

		# Format line-rate values by truncating after the 1000th decimal place.
		rxlr=$(printf "%1.3f" $rxlinerate)
		txlr=$(printf "%1.3f" $txlinerate)
		rxlrint=$(printf "%.0f" $rxlinerate)
		txlrint=$(printf "%.0f" $txlinerate)

		# Print the results
		echo -e "Int: ${INT} | [RX] PPS: ${rxppsnew} | BPS: ${rxbytesnew} | % of LR: $rxlr -- [TX] PPS: ${txppsnew} | BPS: $txbytesnew | % of LR: $txlr"
}

threshold_calculation() {
if [ $1 -gt $CRIT ]; then
	exit $CRITICAL
elif [ $1 -gt $WARN ]; then
	exit $WARNING
else
	exit $OK
fi
}

PPS=0
BPS=0
LINERATE=0
INTERVAL=1
WARN=0
CRIT=0
ARGC=$#

# Check for dependency filesystems
if ! [ -d /sys ] || ! [ -d /proc ]; then
	echo "$0 requires sysfs and procfs"
	exit $UNKNOWN
fi

# Print warning and exit if less than n arguments specified
argcheck 1

# option and argument handling
while getopts "hi:c:w:t:pbr" OPTION
do
     case $OPTION in
         h)
             usage
             exit
             ;;
         i)
	     INT=$OPTARG
	     ;;
         p)
	     PPS=1
	     ;;
         b)
	     BPS=1
	     ;;
         r)
	     LINERATE=1
	     ;;
	 t)
	     INTERVAL=$OPTARG
	     ;;
	 c)
	     CRIT=$OPTARG
	     ;;
	 w)
	     WARN=$OPTARG
	     ;;
	 *)
	     exit $UNKNOWN
             ;;
     esac
done

get_network_data

if [ $PPS -eq 1  ]; then
	threshold_calculation $rxppsnew
elif [ $BPS -eq 1 ]; then
	threshold_calculation $rxbytesnew
elif [ $LINERATE -eq 1 ]; then
	threshold_calculation $rxlrint
else
	echo "Error: Criteria required!"
	exit $UNKNOWN
fi

