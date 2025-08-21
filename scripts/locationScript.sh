#!/bin/bash

# Location Script - Get External IP and Map to City, State
# Author: IT Management Team
# Purpose: Retrieve external IP and geolocation information
# Last Updated: 2025

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Function for logging
log_message() {
    local message="$1"
    local logFile="/var/log/locationScript.log"
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

# Check for required commands
if ! command -v curl &> /dev/null; then
    log_error "curl is required but not installed"
fi

if ! command -v jq &> /dev/null; then
    log_message "WARNING: jq not found, will use alternative parsing method"
    USE_JQ=false
else
    USE_JQ=true
fi

# Function to get external IP address
get_external_ip() {
    local ip=""
    
    # Try multiple IP services for redundancy
    local ip_services=(
        "https://ipinfo.io/ip"
        "https://ifconfig.me/ip"
        "https://icanhazip.com"
        "https://ipecho.net/plain"
    )
    
    for service in "${ip_services[@]}"; do
        log_message "Attempting to get IP from: $service"
        if ip=$(curl -s --max-time 10 --connect-timeout 5 "$service" 2>/dev/null | tr -d '\n\r'); then
            if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                log_message "Successfully retrieved IP: $ip from $service"
                echo "$ip"
                return 0
            else
                log_message "Invalid IP format received from $service: $ip"
            fi
        else
            log_message "Failed to get IP from $service"
        fi
    done
    
    log_error "Unable to retrieve external IP address from any service"
}

# Function to get location information using ipinfo.io
get_location_info() {
    local ip="$1"
    local location_data=""
    
    log_message "Retrieving location data for IP: $ip"
    
    # Get location data from ipinfo.io (free tier)
    if location_data=$(curl -s --max-time 10 --connect-timeout 5 "https://ipinfo.io/$ip/json" 2>/dev/null); then
        if [[ -n "$location_data" ]]; then
            echo "$location_data"
            return 0
        else
            log_error "Empty response from ipinfo.io"
        fi
    else
        log_error "Failed to retrieve location data from ipinfo.io"
    fi
}

# Function to parse location data with jq
parse_location_jq() {
    local location_data="$1"
    local city=""
    local state=""
    local country=""
    local org=""
    
    # Extract information using jq
    city=$(echo "$location_data" | jq -r '.city // "Unknown"' 2>/dev/null)
    state=$(echo "$location_data" | jq -r '.region // "Unknown"' 2>/dev/null)
    country=$(echo "$location_data" | jq -r '.country // "Unknown"' 2>/dev/null)
    org=$(echo "$location_data" | jq -r '.org // "Unknown"' 2>/dev/null)
    
    echo "City: $city"
    echo "State: $state"
    echo "Country: $country"
    echo "Organization: $org"
}

# Function to parse location data without jq (fallback)
parse_location_fallback() {
    local location_data="$1"
    local city=""
    local state=""
    local country=""
    local org=""
    
    # Extract information using grep and sed (basic parsing)
    city=$(echo "$location_data" | grep -o '"city":"[^"]*"' | sed 's/"city":"//;s/"//g' 2>/dev/null || echo "Unknown")
    state=$(echo "$location_data" | grep -o '"region":"[^"]*"' | sed 's/"region":"//;s/"//g' 2>/dev/null || echo "Unknown")
    country=$(echo "$location_data" | grep -o '"country":"[^"]*"' | sed 's/"country":"//;s/"//g' 2>/dev/null || echo "Unknown")
    org=$(echo "$location_data" | grep -o '"org":"[^"]*"' | sed 's/"org":"//;s/"//g' 2>/dev/null || echo "Unknown")
    
    echo "City: $city"
    echo "State: $state"
    echo "Country: $country"
    echo "Organization: $org"
}

# Function to format output for Jamf Pro Extension Attribute
format_jamf_output() {
    local city="$1"
    local state="$2"
    local country="$3"
    local org="$4"
    
    # Format: City, State, Country
    local location_string="$city, $state, $country"
    
    # Clean up the string (remove "Unknown" entries)
    location_string=$(echo "$location_string" | sed 's/, Unknown//g' | sed 's/Unknown, //g' | sed 's/^, //' | sed 's/, $//')
    
    # If we have no valid location data, use organization
    if [[ "$location_string" == "" || "$location_string" == "Unknown" ]]; then
        location_string="$org"
    fi
    
    # Final cleanup
    if [[ "$location_string" == "" || "$location_string" == "Unknown" ]]; then
        location_string="Location Unknown"
    fi
    
    echo "<result>$location_string</result>"
}

# Main execution
main() {
    log_message "Starting location script execution"
    
    # Get external IP
    local external_ip
    external_ip=$(get_external_ip)
    log_message "External IP: $external_ip"
    
    # Get location information
    local location_data
    location_data=$(get_location_info "$external_ip")
    
    # Parse location data
    local parsed_info
    if [[ "$USE_JQ" == "true" ]]; then
        log_message "Using jq for JSON parsing"
        parsed_info=$(parse_location_jq "$location_data")
    else
        log_message "Using fallback parsing method"
        parsed_info=$(parse_location_fallback "$location_data")
    fi
    
    # Extract individual components
    local city=$(echo "$parsed_info" | grep "City:" | cut -d':' -f2 | xargs)
    local state=$(echo "$parsed_info" | grep "State:" | cut -d':' -f2 | xargs)
    local country=$(echo "$parsed_info" | grep "Country:" | cut -d':' -f2 | xargs)
    local org=$(echo "$parsed_info" | grep "Organization:" | cut -d':' -f2 | xargs)
    
    # Log the parsed information
    log_message "Parsed location - City: $city, State: $state, Country: $country, Org: $org"
    
    # Format output for Jamf Pro
    local jamf_output
    jamf_output=$(format_jamf_output "$city" "$state" "$country" "$org")
    
    # Output the result
    echo "$jamf_output"
    
    # Also output detailed information for debugging
    echo "<details>"
    echo "IP: $external_ip"
    echo "City: $city"
    echo "State: $state"
    echo "Country: $country"
    echo "Organization: $org"
    echo "</details>"
    
    log_message "Location script completed successfully"
}

# Execute main function
main "$@"
