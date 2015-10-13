#!/usr/bin/env python
import sys
import datetime
import requests
import json
import imp
import argparse

# Nagios exit codes
nagios_ok       = 0
nagios_warning  = 1
nagios_critical = 2
nagios_unknown  = 3

import argparse
parser = argparse.ArgumentParser(description='Last Crashplan backup check')
parser.add_argument("-s", "--skip", type=str, help="Hosts to skip from backup check")
parser.add_argument("-d", "--device", type=str, help="Specify deviceName to check (def: all)")
parser.add_argument("-H", "--host", type=str, help="<host:port> e.g. crashplan.company.org:443", required=True)
parser.add_argument("-f", "--filename", type=str, help="Filename that contains credentials", required=True)
args = parser.parse_args()

filename        = args.filename
url             = 'https://' + args.host + '/api/DeviceBackupReport?active=true&srtKey=lastConnectedDate'
critical        = 0
single_result   = 0
max_backup_time = 2 # notify if backup is older than x days
status          = 0
if args.skip:
  skip = args.skip.split(",")
else:
  skip = "wutthehelld000d!"

if args.device:
  host = args.device
else:
  host = 0

# Open file
try:
  f = open(filename, "r")
  global data
  creds = imp.load_source('data', '', f)
  f.close()
except IOError:
  print "Could not open file! Does it exist?"
  exit(nagios_unknown)

def backup_check(device, orig_time):
  global status
  if time < critical_days:
    print "CRITICAL: %s: LastCompleteBackup: %s" % (device, orig_time)
    status = nagios_critical
    
def format_time(entry, orig_time):
  global time
  time = datetime.datetime.strptime(orig_time, "%b %d, %Y %I:%M:%S %p")

def check_all_backup(skip):
  for entry in data["data"]:
    device    = entry["deviceName"]
    orig_time = entry["lastCompletedBackupDate"]
    if device in skip:
      continue
    if orig_time is None:
      continue
    format_time(entry, orig_time)
    backup_check(device, orig_time)

def check_host_backup():
  for entry in data["data"]:
    device = entry["deviceName"]
    if device == host:
      orig_time = entry["lastCompletedBackupDate"]
      format_time(entry, orig_time)
      backup_check(device, orig_time)

# Make API request
r = requests.get(url, auth=(creds.user, creds.password))
r.raise_for_status()

data  = r.json()
critical_days = datetime.datetime.now() - datetime.timedelta(days=max_backup_time)

if host == 0:
 check_all_backup(skip)
else:
 check_host_backup()

if status == nagios_critical: 
  exit(nagios_critical)
else:
  print "OK: All backups have been completed recently" 
  exit(nagios_ok)
