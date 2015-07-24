#!/usr/bin/env bash

# Author: Jon Schipp

########
# Examples:

# 1.) Check syslog traffic rate
# $ ./check_traffice.sh -i eth0 -f "port 514" -t 1s -w 500 -c 1000


# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Nagios plug-in that checks packet rate for traffic specified with a bpf

      Options:

      -i 		Network interface
      -f <bpf>		Filter in libpcap syntax
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

depend_check(){
  bin=$(which tcpdump)
  [[ -f $bin ]] || { echo "UNKNOWN: $bin not found in ${PATH}" && exit $UNKNOWN; }
  [[ -d /tmp ]] && DIR=/tmp && return
  [[ -d /var/tmp ]] && DIR=/var/tmp && return
  DIR=.
}

check_bpf () {
  [ "$1" ] || { echo "No BPF specified, use \`\`-f''" && exit $UNKNOWN; }
  exp='\0324\0303\0262\0241\02\0\04\0\0\0\0\0\0\0\0\0\0377\0377\0\0\01\0\0\0'
  echo -en "$exp" | tcpdump -r - "$*" >/dev/null 2>&1 || { echo "UNKNOWN: Invalid BPF" && exit $UNKNOWN; }
}

get_packets() {
  timeout -s SIGINT $TIME tcpdump -nni $INT "$FILTER" 2>/dev/null > $BEFORE
  timeout -s SIGINT $TIME tcpdump -nni $INT "$FILTER" 2>/dev/null > $AFTER
  ! [ -f $BEFORE ] && echo "UNKNOWN: $BEFORE doesn't exist!" && exit $UNKNOWN
  ! [ -f $AFTER ]  && echo "UNKNOWN: $AFTER doesn't exist!"  && exit $UNKNOWN
}

get_counts() {
  START=$(cat $BEFORE | wc -l)
  STOP=$(cat  $AFTER  | wc -l)
  [[ $START -gt $STOP ]] && RESULT=$((START-STOP))
  [[ $STOP -gt $START ]] && RESULT=$((STOP-START))
}

traffic_calculation() {
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
TIME=1
WARN=0
CRIT=0
ARGC=$#
BEFORE=$DIR/check_traffic1.txt
AFTER=$DIR/check_traffic2.txt
# Print warning and exit if less than n arguments specified
argcheck 1
depend_check

# option and argument handling
while getopts "hi:c:f:t:w:" OPTION
do
     case $OPTION in
         h)
             usage
             exit
             ;;
         i)
	     INT=$OPTARG
	     ;;
	 f)
	     FILTER="$OPTARG"
	     ;;
	 t)
	     TIME=$OPTARG
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

[ -d /sys/class/net/$INT ] || { "UNKNOWN: $INT does not exist" && exit $UNKNOWN; }
[ -d /proc ] && check_bpf "$FILTER"
get_packets
get_counts
echo "Traffic rate is ~${RESULT}/${TIME}"
traffic_calculation $RESULT
