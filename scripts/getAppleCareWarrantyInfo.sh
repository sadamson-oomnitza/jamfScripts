#!/bin/bash

# Title:  getAppleCareWarrantyInfo.sh
# Created By:  HCS Technology Group
# Version: 1
# Creation Date: 12-30-24
# Last Modified Date: 12-31-24
# Tested on macOS Version: macOS Ventura - Sequoia
# Contact HCS: info@hcsonline.com
# Visit HCS: https://hcsonline.com
####################################
# This script reads the AppleCare warranty plist located in "/Users/currentUser/Library/Application Support/com.apple.NewDeviceOutreach" to get the expiration date.  
# It requires a Mac that is signed in with an Apple Account and enrolled in Jamf Pro.
####################################
# NOTE: THIS SCRIPT IS PROVIDED AS IS WITHOUT WARRANTY OF ANY KIND. USE IT AT YOUR OWN RISK.
####################################

# Jamf Pro credentials and URL
JAMF_URL="https://YourServer.jamfcloud.com"
client_id="YourClientID"
client_secret="YourClientSecret"

# Obtain the access token
access_token=$(curl --silent --location \
  --request POST "$JAMF_URL/api/oauth/token" \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "client_id=$client_id" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_secret=$client_secret" | plutil -extract "access_token" raw -)

# Get the computer ID based on serial number
get_computer_id() {
    local serialNumber
    serialNumber=$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $4}')
    local computerID

    # Query the Jamf Pro API for computer details based on serial number
    computerID=$(curl -s -H "Accept: text/xml" -H "Authorization: Bearer $access_token" \
        "$JAMF_URL/JSSResource/computers/serialnumber/$serialNumber" | \
        xmllint --xpath '/computer/general/id/text()' - 2>/dev/null)

    if [[ -z "$computerID" ]]; then
        echo "Error: Could not retrieve computer ID for serial number $serialNumber."
        exit 1
    fi

    echo "$computerID"
}

# Get the current logged-in user
loggedInUser=$(echo "show State:/Users/ConsoleUser" | scutil | awk '/Name / { print $3 }')

# Directory containing warranty plist files
PLIST_DIR="/Users/$loggedInUser/Library/Application Support/com.apple.NewDeviceOutreach"

# Check if the directory exists
if [ ! -d "$PLIST_DIR" ]; then
    echo "No plist directory found. Exiting."
    exit 0
fi

# Get the computer ID using the serial number
computerID=$(get_computer_id "$access_token")

# Loop through all plist files in the directory
for plist in "$PLIST_DIR"/*.plist; do
    # Extract deviceDesc from the deviceInfo dictionary
    deviceDesc=$(/usr/libexec/PlistBuddy -c "Print deviceInfo:deviceDesc" "$plist" 2>/dev/null)
    
    # Only process if it's a Mac
    if [[ -z "$deviceDesc" || "$deviceDesc" != *"Mac"* ]]; then
        continue
    fi

    # Read coverageEndDate
    coverageEndDate=$(/usr/bin/defaults read "$plist" coverageEndDate 2>/dev/null)

    # Set to January 1, 2000 if coverageEndDate is not valid
    if [[ -z "$coverageEndDate" ]]; then
        coverageEndDate=$(date -jf "%Y-%m-%d" "2000-01-01" "+%s")
    fi

    # Convert coverageEndDate to YYYY-MM-DD format in UTC
    warrantyDate=$(TZ=UTC date -jf "%s" "$coverageEndDate" "+%Y-%m-%d")

    # Debugging output
    echo "Coverage End Date (Epoch): $coverageEndDate"
    echo "Formatted Warranty Date: $warrantyDate"

    # Update the warranty date using the API command
    response=$(curl -X 'PATCH' \
        "$JAMF_URL/api/v1/computers-inventory-detail/$computerID" \
        -H "accept: application/json" \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: application/json" \
        -d "{
          \"purchasing\": {
            \"warrantyDate\": \"$warrantyDate\"
          }
        }")
    echo "API Response: $response"

    # Invalidate the Bearer token (optional)
    curl -X POST "$JAMF_URL/api/v1/auth/invalidate-token" \
        -H "accept: application/json" \
        -H "Authorization: Bearer $access_token"

    echo "Updated warranty date to $warrantyDate for computer ID $computerID"
done