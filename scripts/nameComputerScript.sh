#!/bin/bash

# Mac Computer Naming Script - Updated for 2025
# Sets computer name based on Serial-DeviceType-ChipType format
# Enhanced with latest Mac model identifiers and improved error handling

# Function for logging
log_message() {
    local message="$1"
    local logFile="/var/log/computerNameScript.log"
    mkdir -p "$(dirname "$logFile")"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $message" | tee -a "$logFile"
}

# Function to get hardware info with fallbacks
get_hardware_info() {
    local field="$1"
    local result
    
    case "$field" in
        "serial")
            result=$(system_profiler SPHardwareDataType | awk -F": " '/Serial Number/{print $2}' | tr -d ' ')
            # Fallback methods for serial number
            if [ -z "$result" ]; then
                result=$(ioreg -l | grep IOPlatformSerialNumber | awk -F'"' '{print $4}')
            fi
            if [ -z "$result" ]; then
                result=$(sysctl -n hw.serialno 2>/dev/null)
            fi
            ;;
        "model")
            result=$(system_profiler SPHardwareDataType | awk -F": " '/Model Identifier/{print $2}' | tr -d ' ')
            # Fallback method
            if [ -z "$result" ]; then
                result=$(sysctl -n hw.model 2>/dev/null)
            fi
            ;;
        "chip")
            # Try multiple approaches for chip detection
            result=$(system_profiler SPHardwareDataType | awk -F": " '/Chip/{print $2}' | tr -d ' ')
            if [ -z "$result" ]; then
                result=$(system_profiler SPHardwareDataType | awk -F": " '/Processor Name/{print $2}' | tr -d ' ')
            fi
            # Additional fallback for Apple Silicon detection
            if [ -z "$result" ]; then
                if sysctl -n machdep.cpu.brand_string 2>/dev/null | grep -q "Apple"; then
                    result="AppleSilicon"
                else
                    result="Intel"
                fi
            fi
            ;;
    esac
    
    echo "$result"
}

# Get hardware information
serialNumber=$(get_hardware_info "serial")
deviceType=$(get_hardware_info "model")
chipType=$(get_hardware_info "chip")

# Validate we got required information
if [ -z "$serialNumber" ]; then
    log_message "ERROR: Unable to retrieve serial number"
    exit 1
fi

if [ -z "$deviceType" ]; then
    log_message "ERROR: Unable to retrieve device model"
    exit 1
fi

if [ -z "$chipType" ]; then
    chipType="Unknown"
fi

log_message "Raw hardware info - Serial: $serialNumber, Model: $deviceType, Chip: $chipType"

# Enhanced device type mapping with latest 2025 models
case "$deviceType" in
    # Legacy string-based matching (older models)
    *"MacBookAir"*) deviceType="MBA" ;;
    *"MacBookPro"*) deviceType="MBP" ;;
    *"iMac"*) deviceType="iMac" ;;
    *"Macmini"*) deviceType="Mini" ;;
    *"MacStudio"*) deviceType="Studio" ;;
    *"MacPro"*) deviceType="Pro" ;;
    
    # iMac Models (Current and Future)
    *"Mac21,1"*|*"Mac21,2"*) deviceType="iMac" ;;
    *"J833"*) deviceType="iMac" ;; # Expected M5 iMac identifier
    
    # MacBook Air Models (Updated with 2025 M4 models)
    *"Mac9,1"*|*"Mac10,1"*) deviceType="MBA" ;;
    *"Mac13,2"*) deviceType="MBA" ;;
    *"Mac14,1"*|*"Mac14,2"*|*"Mac14,15"*) deviceType="MBA" ;;
    *"Mac15,2"*|*"Mac15,12"*|*"Mac15,13"*|*"Mac15,14"*) deviceType="MBA" ;;
    # New 2025 M4 MacBook Air models
    *"Mac16,12"*|*"Mac16,13"*) deviceType="MBA" ;;
    # Future M5 MacBook Air models (expected 2026)
    *"J813"*|*"J815"*) deviceType="MBA" ;;
    
    # MacBook Pro Models (Updated with latest M4 and future M5)
    *"Mac13,3"*|*"Mac13,4"*) deviceType="MBP" ;;
    *"Mac14,5"*|*"Mac14,6"*|*"Mac14,7"*|*"Mac14,9"*|*"Mac14,10"*) deviceType="MBP" ;;
    *"Mac15,3"*|*"Mac15,4"*|*"Mac15,6"*|*"Mac15,7"*|*"Mac15,8"*|*"Mac15,9"*|*"Mac15,10"*|*"Mac15,11"*) deviceType="MBP" ;;
    *"Mac16,1"*|*"Mac16,5"*|*"Mac16,6"*|*"Mac16,7"*|*"Mac16,8"*) deviceType="MBP" ;;
    # Current M4 and future models
    *"Mac17"*|*"Mac18"*) deviceType="MBP" ;;
    # Future M5 MacBook Pro models (expected late 2025)
    *"J614"*|*"J616"*) deviceType="MBP" ;;
    
    # Mac Mini Models (Updated with M4 and future M5)
    *"Mac14,3"*|*"Mac14,12"*) deviceType="Mini" ;;
    *"Mac16,15"*) deviceType="Mini" ;; # M4 Mac Mini
    # Future M5 Mac Mini
    *"J773"*|*"J873"*) deviceType="Mini" ;;
    
    # Mac Studio Models (Current and future)
    *"Mac13,1"*|*"Mac13,2"*) deviceType="Studio" ;;
    *"Mac14,13"*|*"Mac14,14"*) deviceType="Studio" ;;
    # Future Mac Studio models
    *"J775"*) deviceType="Studio" ;;
    
    # Mac Pro Models (Current and future)
    *"Mac7,1"*) deviceType="Pro" ;; # Intel Mac Pro
    *"Mac14,8"*) deviceType="Pro" ;; # Apple Silicon Mac Pro
    # Expected new Mac Pro
    *"J704"*) deviceType="Pro" ;;
    
    # Fallback for unknown models
    *) 
        log_message "WARNING: Unknown device model '$deviceType', using generic 'Mac'"
        deviceType="Mac" 
        ;;
esac

# Enhanced chip type processing
case "$chipType" in
    *"M1"*) chipType="M1" ;;
    *"M2"*) chipType="M2" ;;
    *"M3"*) chipType="M3" ;;
    *"M4"*) chipType="M4" ;;
    *"M5"*) chipType="M5" ;; # Future proofing
    *"M6"*) chipType="M6" ;; # Future proofing
    *"Apple"*) chipType="AS" ;; # Generic Apple Silicon
    *"Intel"*) chipType="Intel" ;;
    *"Core"*) chipType="Intel" ;;
    *) 
        log_message "WARNING: Unknown chip type '$chipType', using 'Unknown'"
        chipType="Unknown" 
        ;;
esac

# Construct the computer name with validation
computerName="${serialNumber}-${deviceType}-${chipType}"

# Enhanced hostname sanitization (RFC compliant)
safeLocalHostName=$(echo "$computerName" | tr -cd 'A-Za-z0-9-' | sed 's/^-*//;s/-*$//')

# Validate final names
if [ ${#computerName} -gt 63 ]; then
    log_message "WARNING: Computer name exceeds 63 characters, truncating"
    computerName="${computerName:0:63}"
fi

if [ ${#safeLocalHostName} -gt 63 ]; then
    log_message "WARNING: Local hostname exceeds 63 characters, truncating"
    safeLocalHostName="${safeLocalHostName:0:63}"
fi

log_message "Setting computer name to: $computerName"
log_message "Setting local hostname to: $safeLocalHostName"

# Set the computer names with error checking
if ! sudo scutil --set ComputerName "$computerName"; then
    log_message "ERROR: Failed to set ComputerName"
    exit 1
fi

if ! sudo scutil --set HostName "$computerName"; then
    log_message "ERROR: Failed to set HostName"
    exit 1
fi

if ! sudo scutil --set LocalHostName "$safeLocalHostName"; then
    log_message "ERROR: Failed to set LocalHostName"
    exit 1
fi

# Enhanced Jamf integration with better error handling
if command -v /usr/local/bin/jamf &> /dev/null; then
    log_message "Jamf binary found, updating Jamf computer name"
    if /usr/local/bin/jamf setComputerName -name "$computerName" 2>&1 | tee -a /var/log/computerNameScript.log; then
        log_message "Successfully updated Jamf computer name"
    else
        log_message "WARNING: Failed to update Jamf computer name, but continuing"
    fi
else
    log_message "Jamf binary not found at /usr/local/bin/jamf, skipping Jamf name update"
    # Check for alternative Jamf locations
    if command -v jamf &> /dev/null; then
        log_message "Found Jamf binary in PATH, attempting update"
        if jamf setComputerName -name "$computerName" 2>&1 | tee -a /var/log/computerNameScript.log; then
            log_message "Successfully updated Jamf computer name using PATH binary"
        else
            log_message "WARNING: Failed to update Jamf computer name using PATH binary"
        fi
    fi
fi

# Verify the changes were applied
actualComputerName=$(scutil --get ComputerName 2>/dev/null)
actualHostName=$(scutil --get HostName 2>/dev/null)
actualLocalHostName=$(scutil --get LocalHostName 2>/dev/null)

log_message "Verification - ComputerName: $actualComputerName"
log_message "Verification - HostName: $actualHostName" 
log_message "Verification - LocalHostName: $actualLocalHostName"

# Final success message
log_message "Script completed successfully. Computer naming updated."

exit 0