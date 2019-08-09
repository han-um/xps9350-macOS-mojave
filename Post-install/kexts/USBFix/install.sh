#!/bin/bash

if [[ $EUID -ne 0 ]];
then
    exec sudo /bin/bash "$0" "$@"
fi

cd "$( dirname "${BASH_SOURCE[0]}" )"

# Clean legacy stuff
#
echo "Cleaning legacy stuff..."
sudo rm -f /usr/local/sbin/sleepwatcher
sudo launchctl unload /Library/LaunchDaemons/com.syscl.externalfix.sleepwatcher.plist 2>/dev/null
sudo rm -f /Library/LaunchDaemons/com.syscl.externalfix.sleepwatcher.plist
sudo rm -f /etc/sysclusbfix.sleep
sudo rm -f /etc/sysclusbfix.wake
sudo rm -f /etc/sysclusbfix.unplug

sudo rm -f /usr/local/sbin/USBFix
sudo launchctl unload /Library/LaunchDaemons/com.maz1.USBFix.plist 2>/dev/null
sudo rm -f /Library/LaunchDaemons/com.maz1.USBFix.plist

# install 
echo "Installing USBFix..."
mkdir -p /usr/local/sbin
sudo cp USBFix /usr/local/sbin
sudo chmod 755 /usr/local/sbin/USBFix
sudo chown root:wheel /usr/local/sbin/USBFix
sudo chmod u+s /usr/local/sbin/USBFix

sudo cp com.maz1.USBFix.plist /Library/LaunchDaemons/
sudo chmod 644 /Library/LaunchDaemons/com.maz1.USBFix.plist
sudo chown root:wheel /Library/LaunchDaemons/com.maz1.USBFix.plist
sudo launchctl load /Library/LaunchDaemons/com.maz1.USBFix.plist
exit 0
