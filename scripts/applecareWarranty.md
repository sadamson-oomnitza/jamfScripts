# AppleCare Warranty Checker Script Explanation

## Overview

The `applecareWarranty.sh` script is a sophisticated automation tool designed to automatically retrieve and update AppleCare warranty information in Jamf Pro. It bridges the gap between Apple's local warranty data and Jamf Pro's inventory management system.

## Purpose

### Problem Statement
Managing warranty information across a fleet of macOS devices can be challenging:
- Manual warranty lookups are time-consuming
- Warranty data is scattered across individual devices
- Jamf Pro inventory lacks automatic warranty updates
- AppleCare information is stored locally but not centrally accessible

### Solution
This script automatically:
1. Reads AppleCare warranty data from local JSON cache files
2. Parses warranty expiration dates
3. Updates Jamf Pro inventory with current warranty information
4. Provides centralized warranty management

### Oomnitza Integration and data improvements
This is a quick overview of taking the updated information in Jamf and enhancing Oomnitza with AppleCare Warranty Information
1. Pulls the data from Jamf Pro into Oomnitza Warranty End date field
2. Improve visibility within Oomnitza to provide EOL or EOW information
3. Better planning with device age and lifecycle
4. Provide insight and value when forecasting device replacement or refresh

## Technical Implementation

### Authentication Flow
```bash
# OAuth 2.0 authentication with Jamf Pro
access_token=$(curl --silent --location \
  --request POST "$JAMF_URL/api/oauth/token" \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "client_id=$client_id" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_secret=$client_secret" | plutil -extract "access_token" raw -)
```

### Device Identification
The script identifies the target device using:
1. **Serial Number Extraction**: Uses `system_profiler` to get the device serial number
2. **Jamf Pro Lookup**: Queries Jamf Pro API to find the computer ID based on serial number
3. **User Context**: Determines the currently logged-in user for file path construction

### Data Source Location
```bash
JSON_DIR="/Users/$loggedInUser/Library/Application Support/com.apple.NewDeviceOutreach/caches/coverageDetails"
```

This directory contains JSON files with AppleCare warranty information that Apple's system creates when a user is signed in with their Apple ID.

### JSON Parsing Strategy

#### Primary Method (jq)
```bash
coverageExpirationLabel=$(jq -r '.settingsCoverageSection.coverageExpirationLabel // empty' "$json_file")
serialNumber=$(jq -r '.serialNumber // empty' "$json_file")
```

#### Fallback Method (Python3)
If `jq` is not available, the script falls back to Python3 for JSON parsing:
```python
import json, sys
try:
    with open('$json_file', 'r') as f:
        data = json.load(f)
    label = data.get('settingsCoverageSection', {}).get('coverageExpirationLabel', '')
    print(label)
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
```

### Date Parsing Logic

The script handles multiple date formats through a cascading parsing approach:

1. **US Format**: "May 8, 2026" → `%B %d, %Y`
2. **US Short Month**: "May 8, 2026" → `%b %d, %Y`
3. **International Format**: "8 May 2026" → `%d %B %Y`
4. **International Short Month**: "8 May 2026" → `%d %b %Y`

```bash
if warrantyDate=$(date -jf "%B %d, %Y" "$dateString" "+%Y-%m-%d" 2>/dev/null); then
    echo "Successfully parsed date (US format): $warrantyDate"
elif warrantyDate=$(date -jf "%b %d, %Y" "$dateString" "+%Y-%m-%d" 2>/dev/null); then
    echo "Successfully parsed date (US short month): $warrantyDate"
# ... additional formats
```

### Jamf Pro API Integration

The script updates Jamf Pro using the REST API:
```bash
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
```

## Usage Scenarios

### 1. Automated Warranty Management
- **Deploy via Jamf Pro**: Run as a policy to update warranty information across all devices
- **Scheduled Execution**: Set up recurring policies to keep warranty data current
- **On-Demand Updates**: Run manually when warranty information needs verification

### 2. Asset Lifecycle Management
- **Warranty Expiration Alerts**: Use updated warranty dates to trigger alerts
- **Replacement Planning**: Identify devices approaching warranty expiration
- **Budget Planning**: Track warranty coverage across the fleet

### 3. Compliance and Reporting
- **Warranty Coverage Reports**: Generate reports on warranty status
- **Audit Preparation**: Ensure warranty information is accurate for audits
- **Vendor Management**: Track AppleCare coverage for vendor relationships

## Prerequisites

### System Requirements
- macOS Ventura or later
- Device signed in with Apple ID
- Jamf Pro enrollment
- Network connectivity to Jamf Pro server

### Dependencies
- `curl` (built-in)
- `jq` (preferred) or `python3` (fallback)
- `system_profiler` (built-in)
- `xmllint` (built-in)
- `plutil` (built-in)

### Jamf Pro Configuration
- API client with appropriate permissions
- Script parameters configured:
  - Parameter 4: Jamf Pro URL
  - Parameter 5: Client ID
  - Parameter 6: Client Secret

## Error Handling

### Graceful Degradation
- **Missing JSON Directory**: Script exits cleanly if no warranty data is found
- **No JSON Files**: Continues processing if directory exists but is empty
- **Parsing Failures**: Uses default date (2000-01-01) if date parsing fails
- **API Failures**: Provides detailed error messages for troubleshooting

### Debugging Features
- Extensive logging output for troubleshooting
- File-by-file processing status
- Date parsing validation
- API response tracking

## Security Considerations

### Authentication
- Uses OAuth 2.0 client credentials flow
- Bearer tokens are invalidated after use
- Credentials passed via Jamf Pro parameters (not hardcoded)

### Data Privacy
- Only reads local warranty data
- No personal information transmitted beyond warranty dates
- Respects user privacy and data protection

## Limitations

### Apple ID Dependency
- Requires user to be signed in with Apple ID
- Won't work on devices without Apple ID sign-in
- Limited to devices with AppleCare coverage

### File Format Dependency
- Relies on Apple's JSON file format
- May break if Apple changes their data structure
- Requires specific directory structure

### Network Dependency
- Requires connectivity to Jamf Pro server
- API calls may fail during network issues
- Authentication requires internet access

## Best Practices

### Deployment
1. **Test First**: Always test in a non-production environment
2. **Gradual Rollout**: Deploy to a small group before full deployment
3. **Monitor Logs**: Review script output for errors or issues
4. **Regular Updates**: Keep the script updated as Apple changes their format

### Maintenance
1. **Regular Execution**: Run periodically to keep warranty data current
2. **Error Monitoring**: Set up alerts for script failures
3. **Version Control**: Track script versions and changes
4. **Documentation**: Keep deployment and configuration notes

## Troubleshooting

### Common Issues

1. **"No JSON directory found"**
   - User not signed in with Apple ID
   - AppleCare data not available for device

2. **"Could not retrieve computer ID"**
   - Device not enrolled in Jamf Pro
   - API permissions insufficient
   - Network connectivity issues

3. **"Could not parse date format"**
   - Apple changed date format
   - Non-standard date string in JSON

4. **API authentication failures**
   - Invalid credentials
   - Expired client secret
   - Incorrect Jamf Pro URL

### Debug Steps
1. Check script parameters in Jamf Pro
2. Verify user is signed in with Apple ID
3. Confirm device enrollment in Jamf Pro
4. Test API connectivity manually
5. Review script logs for specific error messages

## Future Enhancements

### Potential Improvements
- Support for multiple Apple IDs per device
- Batch processing for multiple devices
- Integration with other asset management systems
- Enhanced error reporting and alerting
- Support for additional warranty types beyond AppleCare

### Compatibility Updates
- Monitor Apple's file format changes
- Update date parsing for new formats
- Enhance API integration for newer Jamf Pro versions
- Add support for additional macOS versions

---

*This script represents a sophisticated approach to automating warranty management in enterprise environments, providing significant time savings and improved accuracy in asset tracking.*
