#!/usr/bin/env python
import requests
import datetime
import json
import imp

filename = '/root/crashplan-credentials-for-nagios.txt'
# replace host with your crashplan server
url = 'https://crashplan.company.com:4285/api/DeviceBackupReport?active=true&srtKey=lastConnectedDate'

# Nagios exit codes
nagios_ok       = 0
nagios_warning  = 1
nagios_critical = 2
nagios_unknown  = 3

try:
  f = open(filename, "r")
except IOError:
  print "Could not open credential file! Does it exist?"
  exit(nagios_unknown)

global data
creds = imp.load_source('data', '', f)
f.close()

r = requests.get(url, auth=(creds.user, creds.password))
r.raise_for_status()

data  = r.json()
two_days_ago = datetime.datetime.now() - datetime.timedelta(days=2)

for entry in data["data"]:
  device = entry["deviceName"]
  orig_time   = entry["lastCompletedBackupDate"]
  if orig_time is None:
    continue
  time = datetime.datetime.strptime(orig_time, "%b %d, %Y %I:%M:%S %p")
  if time < two_days_ago:
    print "CRITICAL: %s: LastCompleteBackup: %s" % (device, orig_time)
    critical = 1

if critical == 1:
  exit(nagios_critical)

print "OK: All backups have been completed recently" 
exit(nagios_ok)
