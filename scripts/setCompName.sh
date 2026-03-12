#!/bin/bash
# Script: Set Computer Name from Hardware Details
# Purpose: Generates and sets a standardized computer name based on serial,
#          device type, and chip type, then updates Jamf inventory
# Author: Scott Adamson
# Last Updated: 2026-03
# Jamf Pro Compatible: Yes

# Cache system_profiler output once to avoid multiple slow calls
hwInfo=$(system_profiler SPHardwareDataType 2>/dev/null)

# Function to extract an exact field value from cached hardware info
# Uses grep with word-boundary logic to prevent "Model Identifier" matching "Model Name"
get_hardware_detail() {
    echo "$hwInfo" | grep -m1 "^[[:space:]]*${1}:" | awk -F': ' '{print $2}' | xargs
}

# Get hardware info
serialNumber=$(get_hardware_detail "Serial Number (system)" | tr -d ' ')
# Fallback for older macOS where field was just "Serial Number"
[ -z "$serialNumber" ] && serialNumber=$(get_hardware_detail "Serial Number" | tr -d ' ')

modelName=$(get_hardware_detail "Model Name")
deviceType=$(get_hardware_detail "Model Identifier" | tr -d ' ')

# Get chip type - preserve spaces for clean normalization below
chipType=$(get_hardware_detail "Chip")
if [ -z "$chipType" ]; then
    chipType=$(get_hardware_detail "Processor Name")
    [ -z "$chipType" ] && chipType="Intel"
fi

# Normalize chip type:
#   "Apple M5"       -> "M5"
#   "Apple M4 Pro"   -> "M4Pro"
#   "Intel Core i7"  -> "Inteli7"
chipType=$(echo "$chipType" | sed 's/^Apple //' | tr -d ' ' | sed 's/^IntelCore/Intel/')

# Determine short device type
# Check Model Name first (macOS 26+ on Mac17,x and newer returns plain identifier
# like "Mac17,4" with friendly name in separate "Model Name" field)
# Fall back to Model Identifier substring match for older models (e.g. "MacBookAir10,1")
case "$modelName" in
    *"MacBook Air"*)  deviceType="MBA" ;;
    *"MacBook Pro"*)  deviceType="MBP" ;;
    *"iMac"*)         deviceType="iMac" ;;
    *"Mac mini"*)     deviceType="Mini" ;;
    *"Mac Studio"*)   deviceType="MacStudio" ;;
    *"Mac Pro"*)      deviceType="MacPro" ;;
    *)
        # Fallback to Model Identifier for older macOS / edge cases
        case "$deviceType" in
            *"MacBookAir"*)  deviceType="MBA" ;;
            *"MacBookPro"*)  deviceType="MBP" ;;
            *"iMac"*)        deviceType="iMac" ;;
            *"Macmini"*)     deviceType="Mini" ;;
            *"MacStudio"*)   deviceType="MacStudio" ;;
            *"MacPro"*)      deviceType="MacPro" ;;
            # Raw Model Identifiers - iMac
            *"Mac21,1"|*"Mac21,2") deviceType="iMac" ;;
            # MacBook Air - M1/M2/M3/M4 (Mac9–Mac16)
            *"Mac9,1"|*"Mac10,1"|*"Mac13,2"|*"Mac14,1"|*"Mac14,2"|*"Mac14,15"|*"Mac15,2"|*"Mac15,12"|*"Mac15,13"|*"Mac16,12"|*"Mac16,13") deviceType="MBA" ;;
            # MacBook Air - M5 (2026)
            *"Mac17,3"|*"Mac17,4") deviceType="MBA" ;;
            # MacBook Pro - M1/M2/M3/M4 (Mac13–Mac16)
            *"Mac13,3"|*"Mac13,4"|*"Mac14,5"|*"Mac14,6"|*"Mac14,7"|*"Mac14,9"|*"Mac14,10"|*"Mac15,3"|*"Mac15,4"|*"Mac15,6"|*"Mac15,7"|*"Mac15,8"|*"Mac15,9"|*"Mac15,10"|*"Mac15,11"|*"Mac16,1"|*"Mac16,5"|*"Mac16,6"|*"Mac16,7"|*"Mac16,8") deviceType="MBP" ;;
            # MacBook Pro - M5 (2026)
            *"Mac17,5"|*"Mac17,6"|*"Mac17,7"|*"Mac17,8"|*"Mac17,9") deviceType="MBP" ;;
            # Mac mini
            *"Mac14,3"|*"Mac14,12"|*"Mac16,15") deviceType="Mini" ;;
            # Mac Studio
            *"Mac13,1"|*"Mac13,2"|*"Mac14,13"|*"Mac14,14") deviceType="MacStudio" ;;
            # Mac Pro
            *"Mac7,1"|*"Mac14,8") deviceType="MacPro" ;;
            *) deviceType="Mac" ;;
        esac
    ;;
esac

# Construct computer name
computerName="${serialNumber}-${deviceType}-${chipType}"
safeLocalHostName=$(echo "$computerName" | tr -cd 'A-Za-z0-9-' | sed 's/^-*//')

# Set up logging early so errors are also captured
logFile="/var/log/computerNameScript.log"

# Log existing name before making changes
oldComputerName=$(scutil --get ComputerName 2>/dev/null || echo "not set")
oldHostName=$(scutil --get HostName 2>/dev/null || echo "not set")
oldLocalHostName=$(scutil --get LocalHostName 2>/dev/null || echo "not set")
echo "$(date): Current name  - ComputerName: $oldComputerName | HostName: $oldHostName | LocalHostName: $oldLocalHostName" | tee -a "$logFile"
echo "$(date): Attempting to set computer name to: $computerName" | tee -a "$logFile"

# Clear existing names before applying new ones
scutil --set ComputerName "" 2>/dev/null
scutil --set HostName "" 2>/dev/null
scutil --set LocalHostName "" 2>/dev/null

# Apply names and log result
if scutil --set ComputerName "$computerName" && \
   scutil --set HostName "$computerName" && \
   scutil --set LocalHostName "$safeLocalHostName"; then
    echo "$(date): SUCCESS - Computer name updated: [$oldComputerName] -> [$computerName]" | tee -a "$logFile"
else
    echo "$(date): ERROR - Failed to set computer name. Restoring previous name." | tee -a "$logFile"
    # Attempt to restore old names on failure
    scutil --set ComputerName "$oldComputerName" 2>/dev/null
    scutil --set HostName "$oldHostName" 2>/dev/null
    scutil --set LocalHostName "$oldLocalHostName" 2>/dev/null
    exit 1
fi

# Update Jamf inventory if binary is present
jamf_cmd="/usr/local/bin/jamf"
if [[ -x "$jamf_cmd" ]]; then
    "$jamf_cmd" setComputerName -name "$computerName"
    "$jamf_cmd" recon
    echo "$(date): Jamf inventory updated with name $computerName" | tee -a "$logFile"
else
    echo "$(date): WARNING - Jamf binary not found. Skipping inventory update." | tee -a "$logFile"
fi

exit 0
