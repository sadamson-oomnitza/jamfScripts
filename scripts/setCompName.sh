#!/bin/bash
# Script: Set Computer Name from Hardware Details
# Purpose: Generates and sets a standardized computer name based on serial,
#          device type, and chip type, then updates Jamf inventory
# Author: Scott Adamson
# Last Updated: 2026-03
# Jamf Pro Compatible: Yes

# Function to get hardware details
get_hardware_detail() {
    system_profiler SPHardwareDataType | awk -F": " "/$1/{print \$2}" | tr -d ' '
}

# Get hardware info
serialNumber=$(get_hardware_detail "Serial Number")
deviceType=$(get_hardware_detail "Model Identifier")

# Get chip type with fallback for Intel Macs
chipType=$(get_hardware_detail "Chip")
if [ -z "$chipType" ]; then
    chipType=$(get_hardware_detail "Processor Name")
    [ -z "$chipType" ] && chipType="Intel"
fi

# Normalize chip type for cleaner naming
chipType=$(echo "$chipType" | sed 's/AppleM/M/; s/IntelCore/Intel/')

# Determine short device type
# Generic friendly names from system_profiler come first
case "$deviceType" in
    *"MacBookAir"*)  deviceType="MBA" ;;
    *"MacBookPro"*)  deviceType="MBP" ;;
    *"iMac"*)        deviceType="iMac" ;;
    *"Macmini"*)     deviceType="Mini" ;;
    *"MacStudio"*)   deviceType="MacStudio" ;;
    *"MacPro"*)      deviceType="MacPro" ;;
    # Fallback: raw Model Identifiers (edge cases / future models)
    # iMac
    *"Mac21,1"|*"Mac21,2") deviceType="iMac" ;;
    # MacBook Air - M1/M2/M3/M4 (Mac9–Mac16)
    *"Mac9,1"|*"Mac10,1"|*"Mac13,2"|*"Mac14,1"|*"Mac14,2"|*"Mac14,15"|*"Mac15,2"|*"Mac15,12"|*"Mac15,13"|*"Mac16,12"|*"Mac16,13") deviceType="MBA" ;;
    # MacBook Air - M5 (2026)
    *"Mac17,3"|*"Mac17,4") deviceType="MBA" ;;
    # MacBook Pro - M1/M2/M3/M4 (Mac13–Mac16)
    *"Mac13,3"|*"Mac13,4"|*"Mac14,5"|*"Mac14,6"|*"Mac14,7"|*"Mac14,9"|*"Mac14,10"|*"Mac15,3"|*"Mac15,4"|*"Mac15,6"|*"Mac15,7"|*"Mac15,8"|*"Mac15,9"|*"Mac15,10"|*"Mac15,11"|*"Mac16,1"|*"Mac16,5"|*"Mac16,6"|*"Mac16,7"|*"Mac16,8") deviceType="MBP" ;;
    # MacBook Pro - M5 (2026): 14" M5, 14" M5 Pro/Max, 16" M5 Pro/Max
    *"Mac17,5"|*"Mac17,6"|*"Mac17,7"|*"Mac17,8"|*"Mac17,9") deviceType="MBP" ;;
    # Mac mini
    *"Mac14,3"|*"Mac14,12"|*"Mac16,15") deviceType="Mini" ;;
    # Mac Studio
    *"Mac13,1"|*"Mac13,2"|*"Mac14,13"|*"Mac14,14") deviceType="MacStudio" ;;
    # Mac Pro
    *"Mac7,1"|*"Mac14,8") deviceType="MacPro" ;;
    *) deviceType="Mac" ;;
esac

# Construct computer name
computerName="${serialNumber}-${deviceType}-${chipType}"
safeLocalHostName=$(echo "$computerName" | tr -cd 'A-Za-z0-9-' | sed 's/^-*//')

# Set up logging early so errors are also captured
logFile="/var/log/computerNameScript.log"
echo "$(date): Attempting to set computer name to: $computerName" | tee -a "$logFile"

# Apply names and log result
if scutil --set ComputerName "$computerName" && \
   scutil --set HostName "$computerName" && \
   scutil --set LocalHostName "$safeLocalHostName"; then
    echo "$(date): SUCCESS - Computer name set to $computerName" | tee -a "$logFile"
else
    echo "$(date): ERROR - Failed to set computer name" | tee -a "$logFile"
    exit 1
fi

# Update Jamf inventory if binary is present
jamf_cmd="/usr/local/bin/jamf"
if [[ -x "$jamf_cmd" ]]; then
    "$jamf_cmd" setComputerName -name "$computerName"
    echo "$(date): Jamf inventory updated with name $computerName" | tee -a "$logFile"
else
    echo "$(date): WARNING - Jamf binary not found. Skipping inventory update." | tee -a "$logFile"
fi

exit 0
