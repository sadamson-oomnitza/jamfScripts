# Location Script Documentation

## Overview

The Location Script (`locationScript.sh`) is a sophisticated bash script designed to retrieve the external IP address of a macOS device and map it to geographic location information including city, state, and country. This script is optimized for use with Jamf Pro Extension Attributes to provide location-based device management capabilities.

## Purpose

This script serves several important functions in enterprise macOS management:

1. **Device Location Tracking**: Determine the geographic location of devices
2. **Asset Management**: Track device locations for inventory purposes
3. **Security Monitoring**: Identify devices connecting from unexpected locations
4. **Compliance**: Monitor device locations for regulatory requirements
5. **Support**: Provide location context for troubleshooting and support

## Features

### Core Functionality
- **External IP Detection**: Retrieves the device's external IP address
- **Geolocation Mapping**: Maps IP to city, state, and country information
- **Redundant Services**: Uses multiple IP services for reliability
- **Error Handling**: Comprehensive error handling and logging
- **Jamf Pro Integration**: Outputs in Extension Attribute format

### Advanced Features
- **Multiple IP Services**: Fallback to different IP detection services
- **Dual Parsing Methods**: Uses `jq` when available, falls back to basic parsing
- **Detailed Logging**: Comprehensive logging for troubleshooting
- **Network Timeouts**: Configurable timeouts for network requests
- **Data Validation**: Validates IP addresses and location data

## Technical Implementation

### External IP Detection

The script uses multiple IP services for redundancy:

```bash
local ip_services=(
    "https://ipinfo.io/ip"
    "https://ifconfig.me/ip"
    "https://icanhazip.com"
    "https://ipecho.net/plain"
)
```

**Process:**
1. Attempts each service in sequence
2. Validates IP format using regex
3. Returns first valid IP address
4. Logs failures for troubleshooting

### Geolocation Service

Uses **ipinfo.io** (free tier) for geolocation data:
- **API Endpoint**: `https://ipinfo.io/{IP}/json`
- **Response Format**: JSON with city, region, country, org
- **Rate Limits**: 50,000 requests per month (free tier)
- **Accuracy**: City-level accuracy

### Data Parsing

#### Primary Method (jq)
```bash
city=$(echo "$location_data" | jq -r '.city // "Unknown"' 2>/dev/null)
state=$(echo "$location_data" | jq -r '.region // "Unknown"' 2>/dev/null)
country=$(echo "$location_data" | jq -r '.country // "Unknown"' 2>/dev/null)
org=$(echo "$location_data" | jq -r '.org // "Unknown"' 2>/dev/null)
```

#### Fallback Method (grep/sed)
```bash
city=$(echo "$location_data" | grep -o '"city":"[^"]*"' | sed 's/"city":"//;s/"//g')
state=$(echo "$location_data" | grep -o '"region":"[^"]*"' | sed 's/"region":"//;s/"//g')
```

## Usage

### Jamf Pro Extension Attribute

1. **Upload Script**: Upload `locationScript.sh` to Jamf Pro
2. **Create Extension Attribute**:
   - Data Type: String
   - Input Type: Script
   - Script: Select the uploaded script
3. **Deploy**: Assign to appropriate smart groups

### Manual Execution

```bash
# Make executable
chmod +x locationScript.sh

# Run script
./locationScript.sh
```

### Expected Output

#### Jamf Pro Format
```xml
<result>San Francisco, CA, US</result>
<details>
IP: 192.168.1.100
City: San Francisco
State: CA
Country: US
Organization: Comcast Cable Communications
</details>
```

#### Alternative Outputs
- `New York, NY, US` (Full location available)
- `Comcast Cable Communications` (Location unknown, org available)
- `Location Unknown` (No data available)

## Dependencies

### Required
- **curl**: For HTTP requests to IP and geolocation services
- **bash**: Script execution environment

### Optional
- **jq**: For JSON parsing (enhanced functionality)
- **grep/sed**: For fallback parsing (built-in)

### System Requirements
- **macOS**: Designed for macOS systems
- **Internet Connectivity**: Required for IP and location services
- **Network Access**: Outbound HTTPS access to external services

## Error Handling

### Network Failures
- **Timeout Handling**: 10-second timeout for IP services
- **Connection Limits**: 5-second connection timeout
- **Service Redundancy**: Multiple IP services for reliability
- **Graceful Degradation**: Continues with available data

### Data Validation
- **IP Format Validation**: Regex validation for IP addresses
- **JSON Response Validation**: Checks for valid JSON responses
- **Empty Response Handling**: Handles empty or invalid responses
- **Fallback Parsing**: Uses alternative parsing when jq unavailable

### Logging
- **Log File**: `/var/log/locationScript.log`
- **Timestamped Entries**: All operations logged with timestamps
- **Error Logging**: Errors logged to both stderr and log file
- **Debug Information**: Detailed logging for troubleshooting

## Use Cases

### 1. Security Monitoring
- **Anomaly Detection**: Identify devices connecting from unexpected locations
- **Geographic Restrictions**: Monitor compliance with location policies
- **Threat Detection**: Flag suspicious location changes

### 2. Asset Management
- **Location Tracking**: Track device locations for inventory
- **Deployment Planning**: Plan device deployments by location
- **Support Coordination**: Route support requests by location

### 3. Compliance and Reporting
- **Geographic Compliance**: Ensure devices comply with location requirements
- **Audit Support**: Provide location data for audits
- **Regulatory Reporting**: Generate location-based reports

### 4. Jamf Pro Integration
- **Smart Groups**: Create location-based device groups
- **Policies**: Trigger actions based on device location
- **Reporting**: Generate location-based inventory reports

## Best Practices

### Deployment
1. **Test First**: Always test on a small group before full deployment
2. **Monitor Logs**: Review script logs after deployment
3. **Validate Output**: Ensure location data is accurate
4. **Rate Limiting**: Be aware of API rate limits

### Smart Group Examples

#### Devices in Specific City
```
Extension Attribute: location
Operator: contains
Value: San Francisco
```

#### Devices Outside Country
```
Extension Attribute: location
Operator: does not contain
Value: US
```

#### Remote Workers
```
Extension Attribute: location
Operator: does not contain
Value: [Office City]
```

### Policy Integration
- **Location-Based Policies**: Trigger actions based on device location
- **Security Policies**: Restrict access based on location
- **Support Policies**: Route support requests by location

## Troubleshooting

### Common Issues

1. **"Unable to retrieve external IP address"**
   - Network connectivity issues
   - Firewall blocking outbound connections
   - All IP services unavailable

2. **"Failed to retrieve location data"**
   - ipinfo.io service unavailable
   - Rate limit exceeded
   - Network timeout

3. **"Location Unknown"**
   - Invalid IP address
   - No geolocation data available
   - Parsing failure

4. **Empty or incorrect output**
   - Script execution failure
   - Permission denied
   - Jamf Pro integration issues

### Debug Steps
1. **Check Network**: Verify internet connectivity
2. **Test Manual Execution**: Run script directly on device
3. **Review Logs**: Check `/var/log/locationScript.log`
4. **Verify Services**: Test IP services manually
5. **Check Permissions**: Ensure script is executable

### Log Analysis
```bash
# View recent log entries
tail -f /var/log/locationScript.log

# Search for errors
grep "ERROR" /var/log/locationScript.log

# Check successful executions
grep "completed successfully" /var/log/locationScript.log
```

## Security Considerations

### Privacy
- **External Services**: Data sent to third-party services
- **IP Address Exposure**: External IP is revealed to services
- **Location Data**: Geographic location is determined and logged

### Network Security
- **HTTPS Only**: All requests use encrypted connections
- **Timeout Limits**: Prevents hanging connections
- **Service Validation**: Validates responses from external services

### Data Handling
- **Local Processing**: All parsing occurs locally
- **Minimal Logging**: Only technical information logged
- **No Personal Data**: No user personal information collected

## Limitations

### API Limitations
- **Rate Limits**: 50,000 requests/month (ipinfo.io free tier)
- **Accuracy**: City-level accuracy, not street-level
- **Coverage**: May not work for all IP addresses

### Network Dependencies
- **Internet Required**: Cannot function without internet access
- **Service Availability**: Depends on external service availability
- **Firewall Issues**: May be blocked by corporate firewalls

### Data Accuracy
- **VPN Impact**: VPN usage affects location accuracy
- **Mobile Networks**: Mobile IPs may show carrier location
- **Corporate Networks**: Corporate IPs may show company location

## Future Enhancements

### Planned Improvements
- **Multiple Geolocation Services**: Fallback to other services
- **Caching**: Cache results to reduce API calls
- **Custom API Keys**: Support for paid API tiers
- **Historical Tracking**: Track location changes over time
- **Integration APIs**: Direct integration with monitoring systems

### Compatibility Updates
- **New macOS Versions**: Support for upcoming releases
- **Jamf Pro Features**: Integration with new Jamf capabilities
- **API Changes**: Adapt to service API changes

---

*This script provides reliable device location tracking for macOS devices in enterprise environments, enabling location-based management and security monitoring.*
