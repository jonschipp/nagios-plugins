nagios-plugins
==============

A collection of Nagios Plugins I've written for production unix environments.

A few of the scripts like check_service.sh and check_volume.sh are designed to
be run in heterogenous unix environments and should work on Linux, OSX, AIX, and
the BSD's provided a bash or bash-compatible shell to interpret them.

Each script has detailed usage presentable via the ``-h'' option and some of
scripts include extended usage examples within the top commented section of the script.

One way to run the plugins requiring elevated privileges is to
configure sudo on each monitored machine to allow the nagios
user to execute the plug-ins in the plug-in directory as root:
```
$ visudo # Use visudo to edit the sudoers file , or :
$ echo ’Defaults:nagios !requiretty ’ >> /etc/sudoers
$ echo ’nagios ALL=(root) NOPASSWD:/usr/local/nagios/libexec/∗’ >> /etc/sudoers
```

If that is the case be sure to limit write permissions for the scripts so that
one cannot simply update the scripts with malicious code.

### Plugins:

#### Heterogenous Unix (Unices):

**check_load.sh** - Check a system's load (run queue) via ``uptime''.

**check_service.sh** - Check the status of a system service.

**check_volume.sh** - Check free space for a volume or partition.

**check_file_growth.sh** - Check whether a file is growing in size (e.g. Monitor for stale log files).

**check_filesystem_stat.sh** - Recursively checks for filesystem input/output errors by directory using stat.

**check_status_code.sh** - Checks exit code of another program and returns a custom Nagios status code based on the result.

#### OSX only:

**check_osx_raid.sh** - Check RAID status of a disk. (Find degraded and failing arrays).

**check_osx_smart.sh** - Check S.M.A.R.T status of a disk. (Find failing disks).

**check_osx_temp.sh** - Check temperature of system components. (Find systems running hot).

#### Linux only:

**check_connections.sh** - Check number of connections/sockets in a given state. Requires iproute2. (Find 10000+ EST connections)

**check_pps.sh** - Check PPS, BPS, or percentage of line-rate on a networking interface (Find periods of heavy traffic)

#### Application specific:

**check_ossec.sh** - Perform multiple checks for a OSSEC server (e.g. Find a disconnected agent).

**check_bro.sh** - Perform multiple checks for a Bro cluster (e.g. Find stopped workers).

**check_enq.sh** - Check status of a printer queue on AIX (Find queues in DOWN state)

**check_rsyslog.sh** - Check for rsyslog disk queue buffers (Find when logs are buffered)

