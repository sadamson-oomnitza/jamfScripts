#!/bin/bash

# Title:  getAppleCareWarrantyInfo_JSON.sh
# Created By:  HCS Technology Group
# Version: 2 (Converted to JSON)
# Creation Date: 12-30-24
# Last Modified Date: 12-31-24
# Tested on macOS Version: macOS Ventura - Sequoia
# Contact HCS: info@hcsonline.com
# Visit HCS: https://hcsonline.com
####################################
# This script reads the AppleCare warranty JSON located in "/Users/$loggedInUser/Library/Application Support/com.apple.NewDeviceOutreach/caches/coverageDetails" to get the expiration date.
# It requires a Mac that is signed in with an Apple Account and enrolled in Jamf Pro.
####################################
# NOTE: THIS SCRIPT IS PROVIDED AS IS WITHOUT WARRANTY OF ANY KIND. USE IT AT YOUR OWN RISK.
####################################

# Jamf Pro credentials and URL
JAMF_URL="$4"
client_id="$5"
client_secret="$6"

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

# Directory containing warranty JSON files
JSON_DIR="/Users/$loggedInUser/Library/Application Support/com.apple.NewDeviceOutreach/caches/coverageDetails"

# Check if the directory exists
if [ ! -d "$JSON_DIR" ]; then
    echo "No JSON directory found. Exiting."
    exit 0
fi

# Get the computer ID using the serial number
computerID=$(get_computer_id "$access_token")

# Loop through all JSON files in the directory
for json_file in "$JSON_DIR"/*.json; do
    # Check if file exists (in case no .json files are found)
    if [ ! -f "$json_file" ]; then
        echo "No JSON files found in directory."
        continue
    fi

    echo "=== DEBUGGING: Processing file $json_file ==="

    # Extract warranty information from Apple's JSON format
    if command -v jq >/dev/null 2>&1; then
        # Get the coverage expiration label (e.g., "Expires May 8, 2026")
        coverageExpirationLabel=$(jq -r '.settingsCoverageSection.coverageExpirationLabel // empty' "$json_file" 2>/dev/null)
        serialNumber=$(jq -r '.serialNumber // empty' "$json_file" 2>/dev/null)
        
        echo "Found serial number: '$serialNumber'"
        echo "Found coverage label: '$coverageExpirationLabel'"
        
    else
        # Fallback to python if jq is not available
        coverageExpirationLabel=$(python3 -c "
import json, sys
try:
    with open('$json_file', 'r') as f:
        data = json.load(f)
    label = data.get('settingsCoverageSection', {}).get('coverageExpirationLabel', '')
    print(label)
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
" 2>/dev/null)
        
        serialNumber=$(python3 -c "
import json, sys
try:
    with open('$json_file', 'r') as f:
        data = json.load(f)
    print(data.get('serialNumber', ''))
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
" 2>/dev/null)
    fi
    
    # Skip processing if we don't have a coverage expiration label
    if [[ -z "$coverageExpirationLabel" ]]; then
        echo "No coverage expiration found in file: $json_file"
        continue
    fi

    # Parse the coverage expiration label to extract the date
    # Expected format: "Expires May 8, 2026" or similar
    if [[ "$coverageExpirationLabel" =~ [Ee]xpires[[:space:]]+(.+) ]]; then
        dateString="${BASH_REMATCH[1]}"
        echo "Extracted date string: '$dateString'"
        
        # Convert human-readable date to YYYY-MM-DD format
        # Use date command to parse various formats
        if warrantyDate=$(date -jf "%B %d, %Y" "$dateString" "+%Y-%m-%d" 2>/dev/null); then
            echo "Successfully parsed date (US format): $warrantyDate"
        elif warrantyDate=$(date -jf "%b %d, %Y" "$dateString" "+%Y-%m-%d" 2>/dev/null); then
            echo "Successfully parsed date (US short month): $warrantyDate"
        elif warrantyDate=$(date -jf "%d %B %Y" "$dateString" "+%Y-%m-%d" 2>/dev/null); then
            echo "Successfully parsed date (International format): $warrantyDate"
        elif warrantyDate=$(date -jf "%d %b %Y" "$dateString" "+%Y-%m-%d" 2>/dev/null); then
            echo "Successfully parsed date (International short month): $warrantyDate"
        else
            echo "Could not parse date format: '$dateString', using default"
            warrantyDate="2000-01-01"
        fi
    else
        echo "Coverage label doesn't match expected format: '$coverageExpirationLabel'"
        warrantyDate="2000-01-01"
    fi

    # Debugging output
    echo "Processing file: $json_file"
    echo "Serial Number: $serialNumber"
    echo "Coverage Expiration Label: $coverageExpirationLabel"
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

    echo "Updated warranty date to $warrantyDate for computer ID $computerID"
done

# Invalidate the Bearer token (optional)
curl -X POST "$JAMF_URL/api/v1/auth/invalidate-token" \
    -H "accept: application/json" \
    -H "Authorization: Bearer $access_token"

echo "Warranty update process completed."
