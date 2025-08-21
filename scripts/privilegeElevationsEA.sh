#!/bin/bash
# Extension Attribute: Recent Privilege Elevations (Optimized)
# Data Type: String
# Input Type: Script

# Set time range (last 24 hours)
start_time=$(date -v-24H '+%Y-%m-%d %H:%M:%S')

# Single optimized log query - combine all searches into one call
privilege_events=$(timeout 15 log show \
    --predicate '(process == "Jamf Connect" AND (eventMessage CONTAINS "privilege" OR eventMessage CONTAINS "admin" OR eventMessage CONTAINS "TemporaryAdmin")) OR (process == "sudo" AND NOT eventMessage CONTAINS "libsystem_info") OR (process == "authd" AND eventMessage CONTAINS "authenticated" AND (eventMessage CONTAINS "admin" OR eventMessage CONTAINS "sudo"))' \
    --start "$start_time" \
    --style compact \
    --info \
    2>/dev/null)

# Quick processing - extract only the most relevant events
if [[ -n "$privilege_events" ]]; then
    # Count and format in one pass
    filtered_events=$(echo "$privilege_events" | \
        grep -E "(TemporaryAdmin|privilege|admin|sudo)" | \
        grep -v "Retrieve Group\|Retrieve User\|libsystem_info" | \
        tail -10 | \
        sed 's/.*Jamf Connect.*/[JAMF] &/; s/.*sudo.*/[SUDO] &/; s/.*authd.*/[AUTH] &/' | \
        tr '\n' ' | ' | \
        sed 's/ | $//' | \
        cut -c1-1500)
    
    if [[ -n "$filtered_events" ]]; then
        event_count=$(echo "$filtered_events" | grep -o '\[' | wc -l | tr -d ' ')
        echo "<r>[$event_count events] $filtered_events</r>"
    else
        echo "<r>No relevant privilege events in last 24 hours</r>"
    fi
else
    echo "<r>No privilege events detected</r>"
fi