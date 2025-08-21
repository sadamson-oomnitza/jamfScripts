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

# Function to detect VPN, DNS, and networking services
detect_network_services() {
    local vpn_detected=false
    local nextdns_detected=false
    local tailscale_detected=false
    local network_info=""
    
    log_message "Detecting network services and VPN connections"
    
    # Check for VPN connections
    if pgrep -f "openvpn\|vpn\|tunnel" >/dev/null 2>&1; then
        vpn_detected=true
        network_info="$network_info VPN"
        log_message "VPN process detected"
    fi
    
    # Check for Tailscale
    if command -v tailscale >/dev/null 2>&1; then
        if tailscale status >/dev/null 2>&1; then
            tailscale_detected=true
            network_info="$network_info Tailscale"
            log_message "Tailscale detected and active"
        fi
    fi
    
    # Check for NextDNS
    if [[ -f "/etc/resolv.conf" ]]; then
        if grep -q "nextdns" /etc/resolv.conf 2>/dev/null; then
            nextdns_detected=true
            network_info="$network_info NextDNS"
            log_message "NextDNS detected in resolv.conf"
        fi
    fi
    
    # Check for common VPN interfaces
    local vpn_interfaces=("tun0" "tun1" "utun0" "utun1" "ppp0" "ppp1")
    for interface in "${vpn_interfaces[@]}"; do
        if ifconfig "$interface" >/dev/null 2>&1; then
            vpn_detected=true
            network_info="$network_info Interface:$interface"
            log_message "VPN interface detected: $interface"
        fi
    done
    
    # Check for VPN-related system preferences
    if [[ -f "/Library/Preferences/com.apple.networkextension.plist" ]]; then
        if plutil -p "/Library/Preferences/com.apple.networkextension.plist" 2>/dev/null | grep -q "VPN"; then
            vpn_detected=true
            network_info="$network_info SystemVPN"
            log_message "System VPN configuration detected"
        fi
    fi
    
    # Check for common VPN apps
    local vpn_apps=(
        "/Applications/Cisco AnyConnect Secure Mobility Client.app"
        "/Applications/GlobalProtect.app"
        "/Applications/OpenVPN Connect.app"
        "/Applications/Shimo.app"
        "/Applications/Tunnelblick.app"
        "/Applications/Viscosity.app"
        "/Applications/ExpressVPN.app"
        "/Applications/NordVPN.app"
    )
    
    for app in "${vpn_apps[@]}"; do
        if [[ -d "$app" ]]; then
            vpn_detected=true
            network_info="$network_info App:$(basename "$app" .app)"
            log_message "VPN application detected: $app"
        fi
    done
    
    echo "$vpn_detected:$nextdns_detected:$tailscale_detected:$network_info"
}

# Function to get external IP address with VPN/DNS awareness
get_external_ip() {
    local ip=""
    local network_services
    local vpn_detected
    local nextdns_detected
    local tailscale_detected
    local network_info
    
    # Detect network services
    network_services=$(detect_network_services)
    IFS=':' read -r vpn_detected nextdns_detected tailscale_detected network_info <<< "$network_services"
    
    # Log network service detection
    if [[ "$vpn_detected" == "true" ]]; then
        log_message "WARNING: VPN detected - location may not reflect physical location"
    fi
    if [[ "$nextdns_detected" == "true" ]]; then
        log_message "INFO: NextDNS detected - may affect IP geolocation"
    fi
    if [[ "$tailscale_detected" == "true" ]]; then
        log_message "INFO: Tailscale detected - may affect network routing"
    fi
    
    # Try multiple IP services for redundancy
    local ip_services=(
        "https://ipinfo.io/ip"
        "https://ifconfig.me/ip"
        "https://icanhazip.com"
        "https://ipecho.net/plain"
        "https://checkip.amazonaws.com"
        "https://ip.42.pl/raw"
    )
    
    for service in "${ip_services[@]}"; do
        log_message "Attempting to get IP from: $service"
        if ip=$(curl -s --max-time 10 --connect-timeout 5 "$service" 2>/dev/null | tr -d '\n\r'); then
            if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                log_message "Successfully retrieved IP: $ip from $service"
                
                # Add network service context to the output
                if [[ "$vpn_detected" == "true" || "$nextdns_detected" == "true" || "$tailscale_detected" == "true" ]]; then
                    echo "$ip:$network_info"
                else
                    echo "$ip:"
                fi
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
    local network_info="$5"
    
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
    
    # Add network service indicators if detected
    if [[ -n "$network_info" ]]; then
        if echo "$network_info" | grep -q "VPN"; then
            location_string="$location_string [VPN]"
        fi
        if echo "$network_info" | grep -q "NextDNS"; then
            location_string="$location_string [NextDNS]"
        fi
        if echo "$network_info" | grep -q "Tailscale"; then
            location_string="$location_string [Tailscale]"
        fi
    fi
    
    echo "<result>$location_string</result>"
}

# Main execution
main() {
    log_message "Starting location script execution"
    
    # Get external IP with network service detection
    local external_ip_data
    local external_ip
    local network_info
    
    external_ip_data=$(get_external_ip)
    IFS=':' read -r external_ip network_info <<< "$external_ip_data"
    
    log_message "External IP: $external_ip"
    if [[ -n "$network_info" ]]; then
        log_message "Network services detected: $network_info"
    fi
    
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
    jamf_output=$(format_jamf_output "$city" "$state" "$country" "$org" "$network_info")
    
    # Output the result
    echo "$jamf_output"
    
    # Also output detailed information for debugging
    echo "<details>"
    echo "IP: $external_ip"
    if [[ -n "$network_info" ]]; then
        echo "Network Services: $network_info"
    fi
    echo "City: $city"
    echo "State: $state"
    echo "Country: $country"
    echo "Organization: $org"
    echo "</details>"
    
    log_message "Location script completed successfully"
}

# Execute main function
main "$@"
