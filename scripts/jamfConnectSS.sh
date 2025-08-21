#!/bin/bash

# Jamf Connect and Self Service Version Check Script
# Extension Attribute: Jamf Connect and Self Service Status
# Data Type: String
# Input Type: Script
# Purpose: Check and report installed and running versions of Jamf Connect and Self Service

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Function for logging
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # If LOG_FILE is not set, just output to stdout
    if [[ -z "$LOG_FILE" ]]; then
        echo "$timestamp: $message"
        return
    fi
    
    # Try to write to log file, fallback to stdout if permission denied
    if echo "$timestamp: $message" | tee -a "$LOG_FILE" 2>/dev/null; then
        : # Success, do nothing
    else
        # Permission denied or other error, just output to stdout
        echo "$timestamp: $message"
    fi
}

# Function to log errors
log_error() {
    echo "ERROR: $1" >&2
    log_message "ERROR: $1"
    exit 1
}

# Check if we're running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    log_error "This script is designed for macOS only"
fi

# Function to check write permissions and set log location
setup_logging() {
    # Try system log directory first
    if [[ -w "/var/log" ]] || sudo -n test -w "/var/log" 2>/dev/null; then
        LOG_FILE="/var/log/jamfConnectSS.log"
    elif [[ -w "$HOME/Library/Logs" ]]; then
        LOG_FILE="$HOME/Library/Logs/jamfConnectSS.log"
    else
        LOG_FILE="/tmp/jamfConnectSS.log"
    fi
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || {
        echo "WARNING: Cannot create log directory, logging to stdout only"
        LOG_FILE=""
    }
    
    if [[ -n "$LOG_FILE" ]]; then
        log_message "Log file location: $LOG_FILE"
    fi
}

# Setup logging
setup_logging

# Latest version constants (Updated as of 2025)
LATEST_JAMF_CONNECT_VERSION="3.3"
LATEST_SELF_SERVICE_VERSION="2.8"

# Function to check for latest versions from Jamf (if network available)
check_latest_versions() {
    local jamf_connect_latest="$LATEST_JAMF_CONNECT_VERSION"
    local self_service_latest="$LATEST_SELF_SERVICE_VERSION"
    
    log_message "Checking for latest versions from Jamf documentation"
    
    # Try to get latest Jamf Connect version from documentation
    if command -v curl &> /dev/null; then
        # Check Jamf Connect documentation for latest version
        local jamf_connect_doc=$(curl -s --max-time 5 "https://docs.jamf.com/jamf-connect/" 2>/dev/null | grep -o "Jamf Connect [0-9]\+\.[0-9]\+" | head -1 | grep -o "[0-9]\+\.[0-9]\+" || echo "")
        
        if [[ -n "$jamf_connect_doc" ]]; then
            jamf_connect_latest="$jamf_connect_doc"
            log_message "Found latest Jamf Connect version from docs: $jamf_connect_latest"
        else
            log_message "Using default Jamf Connect version: $jamf_connect_latest"
        fi
        
        # Check Self Service documentation for latest version
        local self_service_doc=$(curl -s --max-time 5 "https://docs.jamf.com/self-service/" 2>/dev/null | grep -o "Self Service [0-9]\+\.[0-9]\+" | head -1 | grep -o "[0-9]\+\.[0-9]\+" || echo "")
        
        if [[ -n "$self_service_doc" ]]; then
            self_service_latest="$self_service_doc"
            log_message "Found latest Self Service version from docs: $self_service_latest"
        else
            log_message "Using default Self Service version: $self_service_latest"
        fi
    else
        log_message "curl not available, using default versions"
    fi
    
    echo "$jamf_connect_latest:$self_service_latest"
}

# App locations
jamfConnectLocation="/Applications/Jamf Connect.app"
jamfSelfServiceLocation="/Applications/Self Service.app"
jamfSelfServicePlusLocation="/Applications/Self Service+.app"

log_message "Starting Jamf Connect and Self Service version check"

# Get latest versions (with fallback to defaults)
latest_versions=$(check_latest_versions)
IFS=':' read -r LATEST_JAMF_CONNECT_VERSION LATEST_SELF_SERVICE_VERSION <<< "$latest_versions"

log_message "Using latest versions - Jamf Connect: $LATEST_JAMF_CONNECT_VERSION, Self Service: $LATEST_SELF_SERVICE_VERSION"

# Function to check if app is running
check_app_running() {
    local app_name="$1"
    local bundle_id="$2"
    
    if pgrep -f "$bundle_id" >/dev/null 2>&1; then
        echo "Running"
    else
        echo "Not Running"
    fi
}

# Function to compare versions
compare_versions() {
    local installed_version="$1"
    local latest_version="$2"
    
    if [[ "$installed_version" == "Not installed" ]] || [[ "$installed_version" == "Unable to read version" ]]; then
        echo "Unknown"
    elif [[ "$installed_version" == "$latest_version" ]]; then
        echo "Latest"
    elif [[ "$installed_version" > "$latest_version" ]]; then
        echo "Newer"
    else
        echo "Outdated"
    fi
}

# Check for Jamf Connect
log_message "Checking Jamf Connect installation"
if [[ -d "$jamfConnectLocation" ]]; then
    jamfConnectVersion=$(defaults read "$jamfConnectLocation"/Contents/Info.plist "CFBundleShortVersionString" 2>/dev/null || echo "Unable to read version")
    jamfConnectBundleID=$(defaults read "$jamfConnectLocation"/Contents/Info.plist "CFBundleIdentifier" 2>/dev/null || echo "com.jamf.connect")
    jamfConnectRunning=$(check_app_running "Jamf Connect" "$jamfConnectBundleID")
    jamfConnectStatus=$(compare_versions "$jamfConnectVersion" "$LATEST_JAMF_CONNECT_VERSION")
    
    log_message "Jamf Connect found - Version: $jamfConnectVersion, Status: $jamfConnectStatus, Running: $jamfConnectRunning"
else
    jamfConnectVersion="Not installed"
    jamfConnectRunning="N/A"
    jamfConnectStatus="Not installed"
    log_message "Jamf Connect not installed"
fi

# Check for Jamf Self Service (prioritize Self Service+)
log_message "Checking Self Service installation"
if [[ -d "$jamfSelfServicePlusLocation" ]]; then
    jamfSelfServiceVersion=$(defaults read "$jamfSelfServicePlusLocation"/Contents/Info.plist "CFBundleShortVersionString" 2>/dev/null || echo "Unable to read version")
    jamfSelfServiceBundleID=$(defaults read "$jamfSelfServicePlusLocation"/Contents/Info.plist "CFBundleIdentifier" 2>/dev/null || echo "com.jamf.selfservice")
    jamfSelfServiceType="Self Service+"
    jamfSelfServiceLocation="$jamfSelfServicePlusLocation"
elif [[ -d "$jamfSelfServiceLocation" ]]; then
    jamfSelfServiceVersion=$(defaults read "$jamfSelfServiceLocation"/Contents/Info.plist "CFBundleShortVersionString" 2>/dev/null || echo "Unable to read version")
    jamfSelfServiceBundleID=$(defaults read "$jamfSelfServiceLocation"/Contents/Info.plist "CFBundleIdentifier" 2>/dev/null || echo "com.jamf.selfservice")
    jamfSelfServiceType="Self Service"
    jamfSelfServiceLocation="$jamfSelfServiceLocation"
else
    jamfSelfServiceVersion="Not installed"
    jamfSelfServiceBundleID="N/A"
    jamfSelfServiceType="Not installed"
    jamfSelfServiceLocation="N/A"
fi

# Check if Self Service is running
if [[ "$jamfSelfServiceVersion" != "Not installed" ]]; then
    jamfSelfServiceRunning=$(check_app_running "$jamfSelfServiceType" "$jamfSelfServiceBundleID")
    jamfSelfServiceStatus=$(compare_versions "$jamfSelfServiceVersion" "$LATEST_SELF_SERVICE_VERSION")
    log_message "Self Service found - Type: $jamfSelfServiceType, Version: $jamfSelfServiceVersion, Status: $jamfSelfServiceStatus, Running: $jamfSelfServiceRunning"
else
    jamfSelfServiceRunning="N/A"
    jamfSelfServiceStatus="Not installed"
    log_message "Self Service not installed"
fi

# Format output for Jamf Pro Extension Attribute
if [[ "$jamfConnectStatus" == "Latest" && "$jamfSelfServiceStatus" == "Latest" ]]; then
    # Both are latest
    echo "<result>✅ Jamf Connect $jamfConnectVersion (Latest) | $jamfSelfServiceType $jamfSelfServiceVersion (Latest)</result>"
elif [[ "$jamfConnectStatus" == "Not installed" && "$jamfSelfServiceStatus" == "Not installed" ]]; then
    # Neither installed
    echo "<result>❌ Jamf Connect: Not Installed | Self Service: Not Installed</result>"
elif [[ "$jamfConnectStatus" == "Outdated" || "$jamfSelfServiceStatus" == "Outdated" ]]; then
    # At least one outdated
    echo "<result>⚠️ Jamf Connect $jamfConnectVersion ($jamfConnectStatus) | $jamfSelfServiceType $jamfSelfServiceVersion ($jamfSelfServiceStatus)</result>"
else
    # Mixed status
    echo "<result>ℹ️ Jamf Connect $jamfConnectVersion ($jamfConnectStatus) | $jamfSelfServiceType $jamfSelfServiceVersion ($jamfSelfServiceStatus)</result>"
fi

# Output detailed information for debugging
echo "<details>"
echo "Jamf Connect:"
echo "  Version: $jamfConnectVersion"
echo "  Status: $jamfConnectStatus (Latest: $LATEST_JAMF_CONNECT_VERSION)"
echo "  Running: $jamfConnectRunning"
echo "  Location: $jamfConnectLocation"
echo ""
echo "Self Service:"
echo "  Type: $jamfSelfServiceType"
echo "  Version: $jamfSelfServiceVersion"
echo "  Status: $jamfSelfServiceStatus (Latest: $LATEST_SELF_SERVICE_VERSION)"
echo "  Running: $jamfSelfServiceRunning"
echo "  Location: $jamfSelfServiceLocation"
echo "  Bundle ID: $jamfSelfServiceBundleID"
echo "</details>"

log_message "Jamf Connect and Self Service version check completed successfully"