#!/usr/bin/env python
# Author: Jon Schipp <jschipp@illinois.edu, jonschipp@gmail.com>

# 1.) Check that all OSSEC services are running
# $ ./check_ossec.py -T status

# 2.) Check status of all OSSEC agents except one
# $ ./check_ossec.py -T connected --skip www2.company.com

# 3.) Check status of specific OSSEC agents
# $ ./check_ossec.py -T connected --agents www1.company.com,www2.company.com

# 4.) Report critical if more than 3 agents are offline and warning if at least 1 is offline.
# $ ./check_ossec.py -T connected -c 3 -w 1

# 5.) Check that a syscheck scan as completed for all agents in the last 12 hours, warning if 6
# $ ./check_ossec.py -T syscheck -c 12 -w 6

# 6.) Check that a rootcheck scan as completed for agent in the last 4 hours, warning if 2
# $ ./check_ossec.py -T rootcheck --agents www2.company.com -c 4 -w 2

import sys
import argparse
import os
import subprocess
import datetime
import time

# Nagios exit codes
NAGIOS_OK       = 0
NAGIOS_WARNING  = 1
NAGIOS_CRITICAL = 2
NAGIOS_UNKNOWN  = 3

STATUS_MSG = {
  0:  'OK',
  1:  'WARNING',
  2:  'CRITICAL',
  3:  'UNKNOWN',
}

status_checks=['connected', 'syscheck', 'rootcheck', 'status']

def arguments():
  global path
  # Defaults
  crit = 1
  warn = 1
  path = '/var/ossec'

  parser = argparse.ArgumentParser(description='Check OSSEC Configuration')
  parser.add_argument("-s", "--skip",     type=str, help="Items to skip from check")
  parser.add_argument("-a", "--agents",   type=str, help="Check status of agents (def: all) (sep:,) e.g. www1,www2")
  parser.add_argument("-T", "--type",     type=str, help="Type of check", choices=status_checks)
  parser.add_argument("-p", "--path",     type=str, help="Path of OSSEC directory (def: /var/ossec)")
  parser.add_argument("-c", "--critical", type=int, help="Critical value in count for checks")
  parser.add_argument("-w", "--warning",  type=int, help="Warning value in count for checks")
  args = parser.parse_args()

  option = args.type
  if args.critical:
    crit = args.critical
  if args.warning:
    warn = args.warning

  if args.skip:
    skip = args.skip.split(",")
  else:
    skip = "None"
  if args.agents:
    agents = args.agents.split(",")
  else:
    agents = False
  if args.path:
    path = args.path

  return option, agents, skip, crit, warn

def threshold(inactive_agents, crit, warn):
  if inactive_agents >= crit:
    return NAGIOS_CRITICAL
  if inactive_agents >= warn:
    return NAGIOS_WARNING
  return NAGIOS_OK

def is_ossec(path):
 if os.path.isdir(path):
   files = [
     'etc/ossec.conf',
     'etc/shared/agent.conf',
     'bin/syscheck_control',
     'bin/rootcheck_control',
     'bin/agent_control'
    ]
   for f in files:
     fp = path + '/' + f
     if not os.path.isfile(fp):
       print "Error: Installation missing file %s" % fp
       return False
 return True

def get_output_dict(cmd, arg):
  c=0
  data={}
  command = path + '/' + cmd
  result = subprocess.Popen([command,arg],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  set_result = set(result.stdout)
  for i in set_result:
    data[c]= [i.split(',')]
    c += 1
  return data

def get_output_set(cmd, arg):
  command = path + '/' + cmd
  result = subprocess.Popen([command,arg],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  data = set(result.stdout)
  return data

def is_server():
  filename = '/etc/ossec-init.conf'
  try:
    with open(filename, 'r') as f:
      contents = f.readlines()
      install_type = contents[3].strip().split('=')[1]
    if install_type == '"server"':
      return True
    else:
      print "ERROR: Unable to detect OSSEC server: %s" % install_type
      return False

  except IOError:
    print "ERROR: Cannot open file %s. Is OSSEC installed?" % filename
    exit(NAGIOS_UNKNOWN)

def open_queue(filename, service):
  try:
    with open(filename, 'r') as f:
      for i in f.readlines():
        if service == 'syscheck':
          if 'Starting syscheck scan.' in i:
            syscheck_start_ts = i[1:11]
            return syscheck_start_ts
        if service == 'rootcheck':
          if 'Starting rootcheck scan.' in i:
            rootcheck_start_ts = i[1:11]
            return rootcheck_start_ts
      else:
            return False
  except IOError:
    print "ERROR: Cannot read queue file %s" % filename
    exit(NAGIOS_UNKNOWN)

def older_than(ts, name, crit_ts, warn_ts):
  if not ts:
      print "%s: %s: LastCheckTime: Unknown" % (STATUS_MSG[NAGIOS_UNKNOWN], name)
      return NAGIOS_UNKNOWN
  service_timestamp = datetime.datetime.fromtimestamp(float(ts))
  if service_timestamp < crit_ts:
      print "%s: %s: LastCheckTime: %s" % (STATUS_MSG[NAGIOS_CRITICAL], name, service_timestamp)
      return NAGIOS_CRITICAL
  elif service_timestamp < warn_ts:
          print "%s: %s: LastCheckTime: %s" % (STATUS_MSG[NAGIOS_WARNING], name, service_timestamp)
          return NAGIOS_WARNING
  else:
          return NAGIOS_OK

def check_connected(agents, skip, crit, warn):
  data = get_output_dict('bin/agent_control', '-l')
  c=0
  inactive_agents = 0
  active = [ 'Active', 'Active/Local' ]
  notactive = {}

  for i in data:
    line =  data[c][0]
    c += 1
    # Check for lines with fields we need
    # Extract agent name and status message
    if len(line) == 4:
      name=line[1][6:].lstrip()
      status=line[3].lstrip().rstrip()

      # If --agents is specified only check for specified agents
      if agents:
        if name not in agents:
          continue
      else:
        # If --agents is not specified check all except in skip
        if name in skip:
          continue

      if status not in active:
        notactive[name] = status
        inactive_agents += 1

  # Check if inactive agents were fonud
  if notactive:
    exit_code = threshold(inactive_agents, crit, warn)
    print "%s: %d agents not connected" % (STATUS_MSG[exit_code], len(notactive))
    for k,v in notactive.items():
      print "Name: %s, Status: %s" % (k,v)
    return exit_code
  else:
    print "%s: All agents connected" % STATUS_MSG[NAGIOS_OK]
    return NAGIOS_OK

def check_service(service, agents, skip, crit, warn):
  dir = os.path.join(path,'queue/rootcheck')
  crit_ts = datetime.datetime.now() - datetime.timedelta(hours=crit)
  warn_ts = datetime.datetime.now() - datetime.timedelta(hours=warn)
  status_list = []
  for queue in os.listdir(dir):
     name = queue.strip('()').split()[0].rstrip(')')
     if agents:
       if name not in agents:
         continue
     else:
       if name == 'rootcheck':
         continue
       if name in skip:
         continue
     f = os.path.join(dir, queue)
     if os.path.isfile(f):
       ts = open_queue(f, service)
       status = older_than(ts, name, crit_ts, warn_ts)
     status_list.append(status)
     exit_code = max(status_list)
  if exit_code == NAGIOS_OK:
    print "%s: Agent %s runtimes are up to date" % (STATUS_MSG[NAGIOS_OK],service)
  return exit_code

def check_status(agents, skip):
  data = get_output_set('bin/ossec-control', 'status')
  not_running=[]
  for i in data:
    # If --skip is used skip these
    if i in skip:
      continue
    # Add names of services not running to list
    if 'not running' in i:
      not_running.append(i)
      continue
  # Test for entries in list. Entries mean something wasn't running
  if not_running:
    print "%s: Some services running" % STATUS_MSG[NAGIOS_CRITICAL]
    for i in not_running:
      print i.rstrip()
    return NAGIOS_CRITICAL
  else:
    print "%s: All services running" % STATUS_MSG[NAGIOS_OK]
    return NAGIOS_OK

def main():
  option, agents, skip, crit, warn = arguments()

  if not is_ossec(path):
    exit(NAGIOS_UNKNOWN)
  if not is_server():
    exit(NAGIOS_UNKNOWN)

  if option == "connected":
    exit(check_connected(agents, skip, crit, warn))
  elif option == "syscheck":
    exit(check_service(option, agents, skip, crit, warn))
  elif option == "rootcheck":
    exit(check_service(option, agents, skip, crit, warn))
  elif option == "status":
    exit(check_status(agents, skip))
  else:
    print "Invalid type option"
    exit(NAGIOS_UNKNOWN)

if __name__ == "__main__":
  main()
