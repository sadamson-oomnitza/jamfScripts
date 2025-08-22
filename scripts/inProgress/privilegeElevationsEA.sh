#!/bin/bash
# Extension Attribute: Privilege Elevation Count (Last 24 Hours)
# Data Type: String
# Input Type: Script
# Purpose: Count and report privilege escalations in the last 24 hours

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Function for logging
log_message() {
    local message="$1"
    local logFile="/var/log/privilegeElevationsEA.log"
    mkdir -p "$(dirname "$logFile")"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $message" | tee -a "$logFile"
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

# Set time range (last 24 hours)
start_time=$(date -v-24H '+%Y-%m-%d %H:%M:%S')
current_time=$(date '+%Y-%m-%d %H:%M:%S')

log_message "Scanning privilege escalations from $start_time to $current_time"

# Initialize counters
total_count=0
jamf_count=0
sudo_count=0
authd_count=0
other_count=0

# Query for Jamf Connect privilege escalations
log_message "Querying Jamf Connect privilege events"
jamf_events=$(timeout 15 log show \
    --predicate '(process == "Jamf Connect" AND (eventMessage CONTAINS "privilege" OR eventMessage CONTAINS "admin" OR eventMessage CONTAINS "TemporaryAdmin"))' \
    --start "$start_time" \
    --style compact \
    --info \
    2>/dev/null)

if [[ -n "$jamf_events" ]]; then
    jamf_count=$(echo "$jamf_events" | grep -c "Jamf Connect" || echo "0")
    log_message "Found $jamf_count Jamf Connect privilege events"
fi

# Query for sudo privilege escalations
log_message "Querying sudo privilege events"
sudo_events=$(timeout 15 log show \
    --predicate '(process == "sudo" AND NOT eventMessage CONTAINS "libsystem_info")' \
    --start "$start_time" \
    --style compact \
    --info \
    2>/dev/null)

if [[ -n "$sudo_events" ]]; then
    sudo_count=$(echo "$sudo_events" | grep -c "sudo" || echo "0")
    log_message "Found $sudo_count sudo privilege events"
fi

# Query for authd privilege escalations
log_message "Querying authd privilege events"
authd_events=$(timeout 15 log show \
    --predicate '(process == "authd" AND eventMessage CONTAINS "authenticated" AND (eventMessage CONTAINS "admin" OR eventMessage CONTAINS "sudo"))' \
    --start "$start_time" \
    --style compact \
    --info \
    2>/dev/null)

if [[ -n "$authd_events" ]]; then
    authd_count=$(echo "$authd_events" | grep -c "authd" || echo "0")
    log_message "Found $authd_count authd privilege events"
fi

# Query for other privilege-related events
log_message "Querying other privilege events"
other_events=$(timeout 15 log show \
    --predicate '(eventMessage CONTAINS "privilege" OR eventMessage CONTAINS "admin" OR eventMessage CONTAINS "elevation") AND NOT (process == "Jamf Connect" OR process == "sudo" OR process == "authd")' \
    --start "$start_time" \
    --style compact \
    --info \
    2>/dev/null)

if [[ -n "$other_events" ]]; then
    other_count=$(echo "$other_events" | grep -c "privilege\|admin\|elevation" || echo "0")
    log_message "Found $other_count other privilege events"
fi

# Calculate total count
total_count=$((jamf_count + sudo_count + authd_count + other_count))

log_message "Total privilege escalations in last 24 hours: $total_count"

# Format output for Jamf Pro Extension Attribute
if [[ $total_count -gt 0 ]]; then
    # Create detailed breakdown
    breakdown="J:$jamf_count"
    if [[ $sudo_count -gt 0 ]]; then
        breakdown="$breakdown,S:$sudo_count"
    fi
    if [[ $authd_count -gt 0 ]]; then
        breakdown="$breakdown,A:$authd_count"
    fi
    if [[ $other_count -gt 0 ]]; then
        breakdown="$breakdown,O:$other_count"
    fi
    
    # Get recent examples (last 5 events)
    recent_events=$(timeout 10 log show \
        --predicate '(process == "Jamf Connect" AND (eventMessage CONTAINS "privilege" OR eventMessage CONTAINS "admin" OR eventMessage CONTAINS "TemporaryAdmin")) OR (process == "sudo" AND NOT eventMessage CONTAINS "libsystem_info") OR (process == "authd" AND eventMessage CONTAINS "authenticated" AND (eventMessage CONTAINS "admin" OR eventMessage CONTAINS "sudo"))' \
        --start "$start_time" \
        --style compact \
        --info \
        2>/dev/null | \
        grep -E "(TemporaryAdmin|privilege|admin|sudo)" | \
        grep -v "Retrieve Group\|Retrieve User\|libsystem_info" | \
        tail -5 | \
        sed 's/.*Jamf Connect.*/[JAMF] &/; s/.*sudo.*/[SUDO] &/; s/.*authd.*/[AUTH] &/' | \
        tr '\n' ' | ' | \
        sed 's/ | $//' | \
        cut -c1-1000)
    
    if [[ -n "$recent_events" ]]; then
        echo "<result>$total_count ($breakdown) - Recent: $recent_events</result>"
    else
        echo "<result>$total_count ($breakdown)</result>"
    fi
else
    echo "<result>0 (No privilege escalations in last 24 hours)</result>"
fi

# Also output detailed information for debugging
echo "<details>"
echo "Time Range: $start_time to $current_time"
echo "Total Count: $total_count"
echo "Jamf Connect: $jamf_count"
echo "Sudo: $sudo_count"
echo "Authd: $authd_count"
echo "Other: $other_count"
echo "Breakdown: $breakdown"
echo "</details>"

log_message "Privilege escalation count script completed successfully"