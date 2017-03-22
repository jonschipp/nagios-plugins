#!/usr/bin/env bash

# Author: Jon Schipp
# Date: 11-08-2013
########
# Examples:

# 1.) Check status of all Bro workers
# $ ./check_bro.sh -f /usr/local/bro-2.2/bin/broctl -T status

# 2.) Return average packet loss for the 3 named bro workers
# $ ./check_bro.sh -T loss -i "nids0,nids1,nids2"

# 3.) Check average packet loss of all bro workers against warning and critical thresholds i.e > 10% or 20% packet loss.
# $ ./check_bro.sh -T loss -i all -w 10 -c 20

# 4.) Check packet loss percentage for the last most recent interval from Bro's capture_loss.log above 10% loss.
# $ ./check_bro.sh -f /usr/local/bro-2.2/logs/current/capture_loss.log -T capture_loss -c 10

# 5.) Check average packet loss reported by Myricom's SnifferG driver for each Bro node.
# $ ./check_bro.sh -T myricom -i "192.168.1.254,192.168.1.253" -u bro

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Default location of broctl
# Set this to the proper location if your installation differs or use ``-f''
BROCTL=/usr/local/bro/bin/broctl

# Default location of myri_counters
# Set this to the proper location if your installation differs
MYRI_COUNTERS=/opt/snf/bin/myri_counters

# Default location of logs
# Set this to the proper location if your installation differs
CAPTURE_LOG=/usr/local/bro/logs/current/capture_loss.log
STATS_LOG=/usr/local/bro/logs/current/stats.log

usage()
{
cat <<EOF

Check status of Bro and Bro workers.
This script should be run on the Bro manager.

  Options:
    -c <int>          Critical threshold as percent of packet loss
    -f <path>         Set optional absolute path for broctl, myri_counters, or capture_loss.log
                      Use \`\`-f'' as first option on command-line.
                      (def: $BROCTL,
                      $MYRI_COUNTERS,
                      $CAPTURE_LOG)
    -i <node/worker>  Identifier for Bro instance(s). IP, FQDN, or name depending on the check. (sep:, )
    -p <name>         Print the value of data from Bro e.g. Notice::suppressing or capture_filter
    -T <type>         Check type, "status/loss/capture_loss/myricom/print"
                      status - Check status of all Bro workers
                      loss   - Average packet loss by name for a single
                       > (\`\`-i nids01''), set (\`\`-i "nids01,nids02"), or all workers (\`\`-i all'').
                      capture_loss - Checks for packet loss in capture_loss.log
                      myricom - Average Myricom Sniffer driver packet loss by IP or FQDN for a single-
                       > (\`\`-i 192.168.1.1'') or set (\`\`-i "192.168.1.1,192.168.1.2") of Bro nodes
                       > Connects to nodes via SSH (pub-key auth). If username is not root use ``-u''.
                      print   - Print Bro values
    -u <user>         Username for the myricom check (def: root)
    -w <int>          Warning threshold as percent of packet loss

Usage: $0 -f /usr/local/bro-dev/bin/brotcl -T status
$0 -f /usr/local/bro-2.2/logs/current/capture_loss.log -T capture_loss -c 20
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
CRIT=0
WARN=0
LIST_NODES=0
LOSS_CHECK=0
CAPTURE_LOSS_CHECK=0
STATUS_CHECK=0
PRINT_CHECK=0
MYRI_CHECK=0
MYRI_STATS=0
USER=root
LOSS=0
RECV=0
RUNNING=0
STOPPED=0
CRASHED=0
UNKNOWN_WORKER=0
WORKERS=all
EXCLUDE=none
ARGC=$#

argcheck 1

while getopts "hfc:i:lm:p:T:u:w:" OPTION
do
  case $OPTION in
    h) usage;;
    f)
      shift
      if [[ $1 == *broctl ]]; then
        BROCTL="$1"
      elif [[ $1 == *myri_counters ]]; then
        MYRI_COUNTERS=$1
      elif [[ $1 == *capture_loss.log ]]; then
        CAPTURE_LOG=$1
      # Custom thing written by jazoff - hopefully integrated into Bro upstream sometime
      elif [[ $1 == *current/stats.log ]]; then
        STATS_LOG=$1
      else
        echo "File name appears to be incorrect, maybe try setting the approprate variable in $0."
      fi
      ;;
    c)
      CHECK_THRESHOLD=1
      CRIT="$OPTARG"
      ;;
    l)
      LIST_NODES=1
      ;;
    i)
      if [ $LOSS_CHECK -eq 1 ] && [[ "$OPTARG" == all ]]; then
        WORKERS=".*"
      elif [ $LOSS_CHECK -eq 1 ]; then
        WORKERS=$(echo "$OPTARG" | sed 's/,/:\\|/g')
      elif [ $MYRI_CHECK -eq 1 ]; then
        NODE=$(echo "$OPTARG" | sed 's/,/ /g')
      else
        echo "ERROR: Argument is in incorrect format or \`\`-T <type>'' was not specified first"
        exit $UNKOWN
      fi
      ;;
    p)
      PRINT="$OPTARG"
      ;;
    T)
      if [[ "$OPTARG" == status ]]; then
        STATUS_CHECK=1
      elif [[ "$OPTARG" == myricom ]]; then
        MYRI_CHECK=1
      elif [[ "$OPTARG" == loss ]]; then
        LOSS_CHECK=1
      elif [[ "$OPTARG" == capture_loss ]]; then
        CAPTURE_LOSS_CHECK=1
      elif [[ "$OPTARG" == print ]]; then
        PRINT_CHECK=1
      else
        echo "Unknown argument type"
        exit $UNKNOWN
      fi
      ;;
    u)
      USER="$OPTARG"
      ;;
    w)
      WARN="$OPTARG"
      ;;
    \?)
      exit 1
      ;;
  esac
done

if [ $LOSS_CHECK -eq 1 ] || [ $STATUS_CHECK -eq 1 ] || [ $LIST_NODES -eq 1 ] || [ $PRINT_CHECK -eq 1 ] ; then
  if [ ! -f $BROCTL ];
  then
    echo "ERROR: Broctl has not been found. Update the BROCTL variable in $0 or specify the path with \`\`-f''"
    exit 1
  fi
fi

if [ $LIST_NODES -eq 1 ]; then
  $BROCTL nodes
  exit $OK
fi

if [ $LOSS_CHECK -eq 1 ]; then

  FLOAT_LOSS=$($BROCTL netstats | grep "$WORKERS" | sed 's/[a-z]*=//g' | awk '{ drop += $4 ; link += $5 } END { printf("%f\n", ((drop/NR) / (link/NR))* 100) }')
  LOSS=$(/usr/bin/printf "%d\n" $FLOAT_LOSS 2>/dev/null)

  if [ $LOSS -gt $CRIT ] ;then
    echo "Average packet loss is: $FLOAT_LOSS"
    exit $CRITICAL
  elif [ $LOSS -gt $WARN ]; then
    echo "Average packet loss is: $FLOAT_LOSS"
    exit $WARNING
  else
    echo "Average packet loss is: $FLOAT_LOSS"
    exit $OK
  fi
fi

 # Check status of Bro workers

if [ $STATUS_CHECK -eq 1 ]; then

# Broctl stderr is whitespace separated and we need to match on entire line
IFS=$'\n'
MESSAGE=""
CHECK_NAME="BROCTL STATUS"
for line in $($BROCTL status 2>&1 | grep -v 'Name\|waiting\|Warning')
do
  NAME=$(echo "$line" | awk '{ print $1 }')
  case "$line" in
  *stop*)
    MESSAGE="$MESSAGE $NAME has stopped,"
    STOPPED=$((STOPPED+1))
    ;;
  *fail*)
    MESSAGE="$MESSAGE $NAME has crashed,"
    CRASHED=$((CRASHED+1))
    ;;
  *run*)
    MESSAGE="$MESSAGE $NAME is running,"
    RUNNING=$((RUNNING+1))
    ;;
  *)
    MESSAGE="$MESSAGE Unknown status of worker: $NAME,"
    UNKNOWN_WORKER=$((UNKNOWN_WORKER+1))
    ;;
  esac
done

  if [ $STOPPED -gt 0 ] || [ $CRASHED -gt 0 ] || [ $UNKNOWN_WORKER -gt 0 ]; then
    echo "$CHECK_NAME CRITICAL - $STOPPED stopped workers, $CRASHED crashed workers, $RUNNING running workers, and $UNKNOWN_WORKER workers with an unknown status |$MESSAGE"
    exit $CRITICAL
  else
    echo "$CHECK_NAME OK - All $RUNNING instances are running |$MESSAGE"
    exit $OK
  fi
fi

if [ $CAPTURE_LOSS_CHECK -eq 1 ]; then
  if [ ! -f $CAPTURE_LOG ]; then
    echo "capture_loss.log cannot be found, modify CAPTURE_LOG in $0 or use \`\`-f''"
    exit $UNKNOWN
  fi

  INTERVAL=$(awk 'NR == 9 { printf("%d\n", $2) }' $CAPTURE_LOG)
  TIME=$(date +"%s")
  RECENT=$(echo $((TIME-INTERVAL)))

  awk -v recent=$RECENT -v crit=$CRIT -v loss=0 -v threshold=0 '! /^#/ && $1 > recent && $4 > 0 \
     {
            loss++; decimal=sprintf("%d", $6);
            if ( strtonum(decimal) > crit ) {
  		threshold++
                    print "Peer: "$3,"\t","Loss:", $6;
  	}
     }

    END {
  	 if ( loss >= 1 ) {
                    print "\n--------------------\n"loss,"instances of loss with",threshold,"exceeding the threshold ("crit"%).";
                    if ( threshold > 0 ) {
                            exit 2
                    }
                    exit 0
            }
    else
             print "\nNo loss detected"; }' $CAPTURE_LOG

  if [ $? -eq 2 ]; then
    exit $CRITICAL
  else
    exit $OK
  fi
fi

if [ $PRINT_CHECK -eq 1 ]; then
  $BROCTL print $PRINT
  exit $OK
fi

if [ $MYRI_CHECK -eq 1 ]; then
LOSS=0
RECV=0
COUNT=0
LOSS_TOT=0
RECV_TOT=0
AVERAGE=0

  if [ ! -f $MYRI_COUNTERS ]; then
    echo "ERROR: myri_counters has not been found. Update the MYRI_COUNTERS variable in $0 or specify the path with \`\`-f''"
    exit $UNKOWN
  fi

  for node in $NODE
  do
    MYRI_STATS=$(ssh -l $USER $node $MYRI_COUNTERS | awk -F : '/SNF drop ring full|SNF recv pkts/ { print $2 }' | sed 's/[ \t]*//')
    RECV=$(echo $MYRI_STATS | awk '{ print $1 }')
    LOSS=$(echo $MYRI_STATS | awk '{ print $2 }')
    LOSS_TOT=$((LOSS+LOSS_TOT))
    RECV_TOT=$((RECV+RECV_TOT))
    COUNT=$((COUNT+1))
    echo "$node: Lost $LOSS of $RECV"
  done

  echo "--------------------"

  # Average
  FLOAT_LOSS=$(echo "(($LOSS_TOT / $COUNT) / ($RECV_TOT / $COUNT)) * 100" | bc -l)
  LOSS=$(/usr/bin/printf "%d\n" $FLOAT_LOSS 2>/dev/null)

  if [ $LOSS -gt $CRIT ]; then
    echo "Average packet loss is: $FLOAT_LOSS"
    exit $CRITICAL
  elif [ $LOSS -gt $WARN ]; then
    echo "Average packet loss is: $FLOAT_LOSS"
    exit $WARNING
  else
    echo "Average packet loss is: $FLOAT_LOSS"
    exit $OK
  fi
fi
