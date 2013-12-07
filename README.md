nagios-plugins
==============

A collection of Nagios Plugins I've written for production unix environments.

A few of the scripts like check_service.sh and check_volume.sh are designed to
be run in heterogenous unix environments and should work on Linux, OSX, AIX, and
the BSD's provided a bash or bash-compatible shell to interpret them.

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
