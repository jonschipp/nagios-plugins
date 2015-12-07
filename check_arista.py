#!/usr/bin/env python
# Author: Jon Schipp <jonschipp@gmail.com, jschipp@illinois.edu>
import sys
import os
import argparse
import json
import filecmp
import time
from jsonrpclib import Server

# Nagios exit codes
NAGIOS_OK       = 0
NAGIOS_WARNING  = 1
NAGIOS_CRITICAL = 2
NAGIOS_UNKNOWN  = 3

# Build accepted check type options for argparse
status_checks=['protocol_status', 'interface_status', 'duplex_status', 'bandwidth_status']
rate_checks=['input_rate', 'output_rate']
other_checks=['dumbno', 'link_status', 'traffic_status']
all_checks= status_checks + rate_checks + other_checks

result = NAGIOS_OK

# Create dictionaries to minimize code
DIRECTION_MAP = {
  'input_rate':  'inBitsRate',
  'output_rate': 'outBitsRate',
}

INTERFACE_MAP = {
  'input_rate':  '9/1-24',
  'output_rate': '3/1-16',
}

STATUS_MAP = {
  'interface_status': 'interfaceStatus',
  'protocol_status':  'lineProtocolStatus',
  'duplex_status':    'duplex',
  'bandwidth_status': 'bandwidth',
}

STATUS_MSG = {
  0:  'OK',
  1:  'WARNING',
  2:  'CRITICAL',
  3:  'UNKNOWN',
}

def cred_usage():
  doc = '''
  Could not open file! Does it exist? Is it valid JSON?

  A file containing the API credentials in JSON should be read in using ``-f <file>''
  Its contents should be formatted like this:

  {
    "user":"aristauser",
    "password":"asdfasdfasdfasdf"
  }
  '''[1:]
  return doc

def check_rate(switch, direction, interfaces, skip):
    response = switch.runCmds( 1, ["show interfaces Ethernet" + interfaces] )
    ifs = response[0]["interfaces"]
    d={}
    rc=[]
    for p,info in ifs.items():
      if p in skip:
        continue
      if info["description"] is None:
        continue
      rate = info["interfaceStatistics"].get(direction, 0)  / (1000**2)
      d[p] = [rate, threshold(rate)]
    for nic in d:
      status=d[nic][1]
      rc.append(status)
      print "%s: %s Mbps: %.2f" % (STATUS_MSG[status], nic, d[nic][0])
    return rc

def check_status(switch, option, devices, skip):
    status_type=option
    crit_items=["connected", "up", "duplexFull", 10000000000]
    response = switch.runCmds( 1, ["show interfaces"])
    ifs = response[0]["interfaces"]
    result = NAGIOS_OK
    for p,info in ifs.items():
      if p in skip:
        continue
      if status_type == "bandwidth":
        bw=crit_items[-1]
        if int(info[status_type]) < bw:
          print "CRITICAL: %s Bandwidth: %dGbps" % (p, info[status_type] / (1000**3))
          result = NAGIOS_CRITICAL
          continue
      if devices != "None":
        if p in devices:
          if info[status_type] not in crit_items:
            result = NAGIOS_CRITICAL
            print "CRITICAL: %s %s" % (p, info[status_type])
            continue
          else: print "SUCCESS: %s %s" % (p, info[status_type])
      if devices == "None":
        if info["description"] is None:
          continue
        if status_type not in info:
          continue
        if info[status_type] not in crit_items:
          result = NAGIOS_CRITICAL
          print "CRITICAL: %s  %s" % (p, info[status_type])
    if result == 0: print "SUCCESS: %s check successful" % status_type
    return result

def check_traffic_status(switch, skip):
    response = switch.runCmds( 1, ["show interfaces"])
    ifs = response[0]["interfaces"]
    result = 0
    for p,info in ifs.items():
      if p in skip:
        continue
      if info["description"] is None:
        continue
      if info["lineProtocolStatus"] == "notPresent":
        continue
      if info["interfaceStatus"] == "notconnect":
        continue
      in_traffic = info["interfaceStatistics"]["inPktsRate"]
      out_traffic = info["interfaceStatistics"]["outPktsRate"]
      if in_traffic == 0 and out_traffic == 0:
        print "CRITICAL: %s In: %s Out: %s" % (p, in_traffic, out_traffic)
        result=1
    if result == 1:
      return NAGIOS_CRITICAL
    else:
      print "SUCCESS: Traffic is being processed by all connected interfaces"
      return NAGIOS_OK

def check_dumbno(switch, skip):
    path    = '/root/%s' % os.path.basename(sys.argv[0]) + '-dumbno.state'
    current = path + '.current'
    old     = path + '.old'
    response = switch.runCmds( 1, ["enable", "show ip access-lists"] )
    acl_lists = response[1]["aclList"]
    rules=[]
    for list in acl_lists:
      name = list["name"]
      if name in skip:
        continue
      for rule in list["sequence"]:
        if "permit" in rule["text"]:
          continue
        line = name + " - " + rule["text"]
        rules.append(line)
    if os.path.isfile(current):
      os.rename(current, old)
    save_file(rules, current)
    return compare_file(current, old)

def check_link_status(switch, skip):
    path    = '/root/%s' % os.path.basename(sys.argv[0]) + '-flap.state'
    current = path + '.current'
    old     = path + '.old'
    key = "lastStatusChangeTimestamp"
    response = switch.runCmds( 1, ["show interfaces"])
    ifs = response[0]["interfaces"]
    data=[]
    for p,info in ifs.items():
      if p in skip:
        continue
      if key not in info:
        continue
      print p, info[key]
    if os.path.isfile(current):
      os.rename(current, old)
    save_file(data, current)
    return compare_file(current, old)

def compare_file(current, old):
  if not os.path.isfile(current):
    print "First run, waiting to create history"
    return NAGIOS_UNKNOWN
  if not os.path.isfile(old):
    return NAGIOS_UNKNOWN
  if filecmp.cmp(current, old):
    print "CRITICAL: Entries haven't changed"
    return NAGIOS_CRITICAL
  print "SUCCESS: Entries rules have changed"
  return NAGIOS_OK

def save_file(data, path):
  file = "\n".join(data)
  try:
    with open(path, 'w') as f:
      f.write(file)
  except IOError:
    print "Unable to open file for writing"
    exit(NAGIOS_UNKNOWN)

def threshold(value):
  if value >= crit:
    return NAGIOS_CRITICAL
  if value >= warn:
    return NAGIOS_WARNING
  return NAGIOS_OK

def arguments():
  global crit
  global warn

  parser = argparse.ArgumentParser(description='Check Arista stats')
  parser.add_argument("-s", "--skip",     type=str, help="Items to skip from check")
  parser.add_argument("-d", "--device",   type=str, help="Devices to check (def: all) (sep: ,) e.g. Ethernet1/1/3")
  parser.add_argument("-T", "--type",     type=str, help="Type of check", choices=all_checks)
  parser.add_argument("-H", "--host",     type=str, help="<host:port> e.g. arista.company.org:443", required=True)
  parser.add_argument("-f", "--filename", type=str, help="Filename that contains API credentials", required=True)
  parser.add_argument("-c", "--critical", type=int, help="Critical value in Mbps")
  parser.add_argument("-w", "--warning",  type=int, help="Warning value in Mbps")
  args = parser.parse_args()

  option = args.type
  host = args.host
  filename = args.filename
  crit = args.critical
  warn = args.warning

  if args.skip:
    skip = args.skip.split(",")
  else:
    skip = "None"
  if args.device:
    devices = args.device.split(",")
  else:
    devices = "None"

  return(option, host, filename, devices, skip)

def get_creds(filename):
  try:
    with open(filename, 'r') as f:
      creds = json.load(f)
    return creds
  except IOError:
    print cred_usage()
    exit(NAGIOS_UNKNOWN)

def main():
  option, host, filename, devices, skip = arguments()
  creds = get_creds(filename)
  user = creds["user"]
  password  = creds["password"]

  url    = 'https://' + user + ':' + password + host + '/command-api'
  switch = Server(url)

  if option == "dumbno":
    exit(check_dumbno(switch, skip))
  elif option == "traffic_status":
    exit(check_traffic_status(switch, skip))
  elif option == "link_status":
    exit(check_link_status(switch, skip))
  elif option in status_checks:
    option  =  STATUS_MAP[option]
    exit(check_status(switch, option, devices, skip))
  elif option in rate_checks:
    direction  =  DIRECTION_MAP[option]
    interfaces =  INTERFACE_MAP[option]
    exit(max(check_rate(switch, direction, interfaces, skip)))
  else:
    print "Invalid option"
    exit(NAGIOS_UNKNOWN)

if __name__ == "__main__":
  main()
