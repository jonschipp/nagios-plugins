#!/usr/bin/env bash

# Author: Jon Schipp

########
# Examples:

# 1.) Check status of OSSEC services excluding active response i.e. execd
# $ ./check_ossec.sh -s execd

# 2.) Check status of OSSEC agent
# $ ./check_ossec.sh -a server1

# 3.) Check status of multiple OSSEC agents
# $ ./check_ossec.sh -a "server1,server2,station3"

# 4.) Report critical if more than 3 agents are offline and warning if at least 1 is offline.
# $ ./check_ossec.sh -c 3 -w 1

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Default Location of the binaries
# Set these to the proper location if your installation differs
AGENT_CONTROL=/var/ossec/bin/agent_control
OSSEC_CONTROL=/var/ossec/bin/ossec-control

if [ ! -f $AGENT_CONTROL ] && [ ! -f $OSSEC_CONTROL ];
then
	echo "ERROR: OSSEC binaries not found. If you installed OSSEC in a location other than the default update the AGENT_CONTROL and OSSEC_CONTROL variables in $0."
	exit 1
fi

usage()
{
cat <<EOF

Check for status of OSSEC agents and server.
This script should be run on the OSSEC server.

     Options:
        -a <name>       Check status of agent or list of comma separated agents, "agent1,agent2".
        -c <int>        Critical threshold for number of inactive agents
        -l              List all agents
        -s <service>    Check status of OSSEC server processes. Use ``-s all'' to check all.
			To exclude a service(s) e.g pass as comma separated argument i.e. ``-s "execd,maild''
        -w              Warning threshold for number of inactive agents

Usage: $0 -a "server1,server2,station3"
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
CHECK_AGENT=0
CHECK_THRESHOLD=0
LIST_AGENTS=0
SERVER_CHECK=0
EXCLUDE=all
ACTIVE=0
INACTIVE=0
NEVER=0
TOTAL=0
DISCONNECTED=0
CONNECTED=0
NEVERCONNECTED=0
UNKNOWN=0
ARGC=$#

argcheck 1

while getopts "ha:c:ls:v:w:" OPTION
do
     case $OPTION in
         h)
             usage
             ;;
         a)
             CHECK_AGENT=1
             AGENT="$OPTARG"
             ;;
         c)
             CHECK_THRESHOLD=1
             CRIT="$OPTARG"
             ;;
         l)
             LIST_AGENTS=1
             ;;
         s)
             SERVER_CHECK=1
	     EXCLUDE=$(echo $OPTARG | sed 's/,/|/g')
             ;;
         v)
             CHECK_THRESHOLD=1
             VOL="$OPTARG"
             ;;
         w)
             WARN="$OPTARG"
             ;;
         \?)
             exit 1
             ;;
     esac
done

if [ $LIST_AGENTS -eq 1 ]; then
        $AGENT_CONTROL -l
        exit 0
fi

if [ $SERVER_CHECK -eq 1 ]; then

        $OSSEC_CONTROL status | grep -v -E "$EXCLUDE" | grep "not running"

        if [ $? -eq 0 ]; then
                echo "An OSSEC service is not running!"
                exit $CRITICAL
        else
                echo "All OSSEC services running"
                exit $OK
        fi
fi

if [ $CHECK_AGENT -eq 1 ]; then

        for host in $(echo $AGENT | sed 's/,/ /g');
        do
                RESULT=$($AGENT_CONTROL -l | grep ${host},)

                case $RESULT in

                *Disconnected)
                        echo "Agent $host is not connected!"
                        DISCONNECTED=$((DISCONNECTED+1))
                        ;;
                *Active)
                        echo "Agent $host is connected"
                        CONNECTED=$((CONNECTED+1))
                        ;;
                *Never*)
                        echo "Agent $host has never connected to the server: $RESULT"
                        NEVERCONNECTED=$((NEVERCONNECTED+1))
                        ;;
                *)
                        echo "Unknown status or agent: $host"
                        UNKNOWN=$((UNKNOWN+1))
                        ;;
                esac
        done

        if [ $DISCONNECTED -gt 0 ] || [ $NEVERCONNECTED -gt 0 ] || [ $UNKNOWN -gt 0 ]; then
                echo "-> $DISCONNECTED disconnected agent(s), $NEVERCONNECTED never connected agent(s), and $UNKNOWN agent(s) with unknown status (possible agent name typo?)."
                exit $CRITICAL
        else
                echo "All requested ($CONNECTED) agents are connected to the server!"
                exit $OK
        fi
fi


if [ $CHECK_THRESHOLD -eq 1 ]; then

        ACTIVE=$($AGENT_CONTROL -l | grep Active | wc -l)
        INACTIVE=$($AGENT_CONTROL -l | grep Disconnected | wc -l)
        NEVER=$($AGENT_CONTROL -l | grep Never | wc -l)
        TOTAL=$($AGENT_CONTROL -l | wc -l)

        if [ $INACTIVE -gt $CRIT ]; then
                echo "$INACTIVE of $TOTAL agents inactive! Active: $ACTIVE"
                exit $CRITICAL
        elif [ $INACTIVE -gt $WARN ]; then
                echo "$INACTIVE of $TOTAL agents inactive! Active: $ACTIVE"
                exit $WARNING
        else
                echo "Active: $ACTIVE - Inactive: $INACTIVE - Never connected:$NEVER - Total: $TOTAL"
                exit $OK
        fi

fi
