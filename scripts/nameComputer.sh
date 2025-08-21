#!/bin/bash

# Get the serial number of the Mac
serialNumber=$(system_profiler SPHardwareDataType | awk -F": " '/Serial Number/{print $2}' | tr -d ' ')

# Get the device type (Model Identifier)
deviceType=$(system_profiler SPHardwareDataType | awk -F": " '/Model Identifier/{print $2}' | tr -d ' ')

# Get the chip type (Handles cases where "Chip" may not be present)
chipType=$(system_profiler SPHardwareDataType | awk -F": " '/Chip/{print $2}' | tr -d ' ')
if [ -z "$chipType" ]; then
    chipType=$(system_profiler SPHardwareDataType | awk -F": " '/Processor Name/{print $2}' | tr -d ' ')
    if [ -z "$chipType" ]; then
        chipType="Intel"
    fi
fi

# Determine the short device type
case "$deviceType" in
    
    #Older Mac Models
    *"MacBookAir"*) deviceType="MBA" ;;
    *"MacBookPro"*) deviceType="MBP" ;;
    *"iMac"*) deviceType="iMac" ;;
    *"Macmini"*) deviceType="MacMini" ;;
    *"MacStudio"*) deviceType="MacStudio" ;;
    *"MacPro"*) deviceType="MacPro" ;;
    
    #iMac Models
    *"Mac21,1"*) deviceType="iMac" ;;
    *"Mac21,2"*) deviceType="iMac" ;;
    
    #MacBook Air Models
    *"Mac9,1"*) deviceType="MBA" ;;
    *"Mac10,1"*) deviceType="MBA" ;;
    *"Mac13,2"*) deviceType="MBA" ;;
    *"Mac14,1"*) deviceType="MBA" ;;
    *"Mac14,2"*) deviceType="MBA" ;;
    *"Mac14,15"*) deviceType="MBA" ;;
    *"Mac15,2"*) deviceType="MBA" ;;
    *"Mac15,12"*) deviceType="MBA" ;;
    *"Mac15,13"*) deviceType="MBA" ;;
    *"Mac15,14"*) deviceType="MBA" ;;
    *"Mac16,12"*) deviceType="MBA" ;;
    *"Mac16,13"*) deviceType="MBA" ;;
    
    #MacBook Pro Models
    *"Mac13,3"*) deviceType="MBP" ;;
    *"Mac13,4"*) deviceType="MBP" ;;
    *"Mac14,5"*) deviceType="MBP" ;;
    *"Mac14,6"*) deviceType="MBP" ;;
    *"Mac14,7"*) deviceType="MBP" ;;
    *"Mac14,9"*) deviceType="MBP" ;;
    *"Mac14,10"*) deviceType="MBP" ;;
    *"Mac15,3"*) deviceType="MBP" ;;
    *"Mac15,4"*) deviceType="MBP" ;;
    *"Mac15,6"*) deviceType="MBP" ;;
    *"Mac15,7"*) deviceType="MBP" ;;
    *"Mac15,8"*) deviceType="MBP" ;;
    *"Mac15,9"*) deviceType="MBP" ;;
    *"Mac15,10"*) deviceType="MBP" ;;
    *"Mac15,11"*) deviceType="MBP" ;;
    *"Mac16,1"*) deviceType="MBP" ;;
    *"Mac16,5"*) deviceType="MBP" ;;
    *"Mac16,6"*) deviceType="MBP" ;;
    *"Mac16,7"*) deviceType="MBP" ;;
    *"Mac16,8"*) deviceType="MBP" ;;
    *"Mac17"*) deviceType="MBP" ;;
    *"Mac18"*) deviceType="MBP" ;;
    
    #Mac Mini Models
    *"Mac14,3"*) deviceType="Mini" ;;
    *"Mac14,12"*) deviceType="Mini" ;;
    *"Mac16,15"*) deviceType="Mini" ;;
    
    #Mac Studio Models
    *"Mac13,1"*) deviceType="MacStudio" ;;
    *"Mac13,2"*) deviceType="MacStudio" ;;
    *"Mac14,13"*) deviceType="MacStudio" ;;
    *"Mac14,14"*) deviceType="MacStudio" ;;
    
    #Mac Pro Models
    *"Mac7,1"*) deviceType="MacPro" ;;
    *"Mac14,8"*) deviceType="MacPro" ;;
    *) deviceType="Mac" ;;
esac

# Construct the computer name
computerName="${serialNumber}-${deviceType}-${chipType}"
safeLocalHostName=$(echo "$computerName" | tr -cd 'A-Za-z0-9-')

# Set the computer name, hostname, and sanitized local hostname
sudo scutil --set ComputerName "$computerName"
sudo scutil --set HostName "$computerName"
sudo scutil --set LocalHostName "$safeLocalHostName"

# Check if Jamf is installed before running the command
if command -v /usr/local/bin/jamf &> /dev/null; then
    /usr/local/bin/jamf setComputerName -name "$computerName"
else
    echo "Jamf binary not found. Skipping Jamf name update."
fi

# Logging
logFile="/var/log/computerNameScript.log"
mkdir -p "$(dirname "$logFile")"
echo "$(date): Computer name set to $computerName" | tee -a "$logFile"

exit 0
