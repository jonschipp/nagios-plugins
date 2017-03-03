#!/usr/bin/env bash
# Author: Jon Schipp <jonschipp@gmail.com, jschipp@illinois.edu>
# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Check the number of connections/sockets in a given state.
Uses iproute2's ss tool to retrieve connections.

  Options:
    -s        State of connection (def: all)
    	      (established, syn-sent, syn-recv, fin-wait-1, fin-wait-2, time-wait,
    	           closed, close-wait, last-ack, listen, and closing)
    -f 	      Apply quoted ss expression filter e.g. '( dst 192.168.1/24 and dport >= :1024 )'
    -p <type> Set protocol or family type (udp/tcp/inet/inet6)
    -c        Critical threshold as an integer
    -w        Warning threshold as an integer
    -e        Exact count mode (raise CRITICAL if connection != critical, warn is ignored)

Usage: $0 -s established '( sport = :443 )' -w 800 -c 1000
EOF
}

argcheck() {
# if less than n argument
if [ $ARGC -lt $1 ]; then
  echo "Missing arguments! Use \`\`-h'' for help."
  exit 1
fi
}

if ! command -v ss >/dev/null 2>&1; then
  echo -e "ERROR: ss is not installed or not found in \$PATH!"
  exit 1
fi

# Define now to prevent expected number errors
STATE=all
CRIT=100
WARN=50
COUNT=0
ARGC=$#
CHECK=0
EXACT=0

argcheck 1

while getopts "hc:s:f:p:w:e" OPTION
do
  case $OPTION in
    h)
      usage
      ;;
    s)
      STATE="$OPTARG"
      CHECK=1
      ;;
    f)
      FILTER="$OPTARG"
      CHECK=1
      ;;
    p)
      if [[ $OPTARG == tcp ]]; then
        PROTOCOL="-t"
      elif [[ $OPTARG == udp ]]; then
        PROTOCOL="-u"
      elif [[ $OPTARG == inet ]]; then
        PROTOCOL="-4"
      elif [[ $OPTARG == inet6 ]]; then
        PROTOCOL="-6"
      else
        echo "Error: Protocol or family type no valid!"
      exit 1
      fi
      CHECK=1
      ;;
    c)
      CRIT="$OPTARG"
      CHECK=1
      ;;
    w)
      WARN="$OPTARG"
      CHECK=1
      ;;
	e)
	  EXACT=1
	  ;;
    \?)
      exit 1
      ;;
  esac
done

COUNT=$(ss -n state $STATE $PROTOCOL $FILTER | grep -v 'State\|-Q' | wc -l)

if [ $EXACT -eq 1 ]; then

  echo "$COUNT sockets in $STATE state"
  if [ $COUNT -ne $CRIT ]; then
    exit $CRITICAL
  else
    exit $OK
  fi

elif [ $COUNT -gt $CRIT ]; then
  echo "CRITICAL - $COUNT sockets in $STATE state! | connections=$COUNT;$WARN;$CRIT"
  exit $CRITICAL
elif [ $COUNT -gt $WARN ]; then
  echo "WARNING - $COUNT sockets in $STATE state! | connections=$COUNT;$WARN;$CRIT"
  exit $WARNING
else
  echo "OK - $COUNT sockets in $STATE state. | connections=$COUNT;$WARN;$CRIT"
  exit $OK
fi
