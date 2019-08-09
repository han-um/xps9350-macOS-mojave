#!/bin/bash
cd `dirname $0`

# Clean legacy stuff
#

sudo rm /usr/local/sbin/sleepwatcher
sudo launchctl unload /Library/LaunchDaemons/com.syscl.externalfix.sleepwatcher.plist
sudo rm /Library/LaunchDaemons/com.syscl.externalfix.sleepwatcher.plist
sudo rm /etc/sysclusbfix.sleep
sudo rm /etc/sysclusbfix.wake

# install 
sudo cp sleepwatcher /usr/local/sbin
sudo chmod 755 /usr/local/sbin/sleepwatcher
sudo chown root:wheel /usr/local/sbin/sleepwatcher
sudo cp sysclusbfix.sleep /etc/
sudo cp sysclusbfix.wake /etc/
sudo cp com.syscl.externalfix.sleepwatcher.plist /Library/LaunchDaemons/
sudo chmod 644 /Library/LaunchDaemons/com.syscl.externalfix.sleepwatcher.plist
sudo chown root:wheel /Library/LaunchDaemons/com.syscl.externalfix.sleepwatcher.plist
sudo launchctl load /Library/LaunchDaemons/com.syscl.externalfix.sleepwatcher.plist
exit 0
