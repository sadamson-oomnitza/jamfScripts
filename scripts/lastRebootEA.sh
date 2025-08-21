#!/bin/bash

# Enhanced script to get macOS boot time with error handling
# Author: IT Management Team
# Purpose: Retrieve system boot time in ISO 8601 format

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Function to log errors
log_error() {
    echo "ERROR: $1" >&2
    exit 1
}

# Check if we're running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    log_error "This script is designed for macOS only"
fi

# Get boot time of the device (kernel) - using original working method
bootTime=$(sysctl kern.boottime | awk '{print $5}' | tr -d ',') || {
    log_error "Failed to retrieve boot time from kernel"
}

# Debug: Show what we extracted (remove this line after testing)
echo "DEBUG: Extracted timestamp: $bootTime" >&2

# Validate that we got a numeric timestamp
if ! [[ "$bootTime" =~ ^[0-9]+$ ]]; then
    log_error "Invalid boot time retrieved: $bootTime"
fi

# Convert boot time to ISO 8601 format with timezone
prettyDate=$(date -jf %s "$bootTime" +%Y-%m-%dT%H:%M:%S%z 2>/dev/null) || {
    log_error "Failed to convert timestamp to date format"
}

# Output the result
echo "<result>$prettyDate</result>"

# Optional: Also show uptime for reference
uptime_seconds=$(($(date +%s) - bootTime))
uptime_days=$((uptime_seconds / 86400))
uptime_hours=$(((uptime_seconds % 86400) / 3600))
uptime_minutes=$(((uptime_seconds % 3600) / 60))

echo "<uptime>${uptime_days}d ${uptime_hours}h ${uptime_minutes}m</uptime>"