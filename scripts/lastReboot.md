# Last Reboot Scripts Documentation

## Overview

The Last Reboot Scripts provide functionality to retrieve and report the system boot time of macOS devices. These scripts are designed for use with Jamf Pro to collect system uptime information for inventory management and troubleshooting purposes.

## Script Versions

### Enhanced Version: `lastRebootEA.sh` (v2.0)
**Last Updated:** 2025  
**Compatibility:** macOS Ventura - Sequoia  

Advanced version with comprehensive error handling, validation, and additional uptime information.

### Basic Version: `lastReboot.sh` (v1.0)
**Last Updated:** 2024  
**Compatibility:** macOS Ventura - Sequoia  
**Status:** Basic functionality

Simple version that provides basic boot time retrieval without error handling.

## Purpose

These scripts serve several important functions in enterprise macOS management:

1. **System Uptime Monitoring**: Track how long devices have been running
2. **Troubleshooting**: Identify devices that may need restarts
3. **Compliance**: Monitor system stability and uptime patterns
4. **Inventory Management**: Collect boot time data for asset tracking
5. **Maintenance Planning**: Identify devices due for maintenance restarts

## Key Differences Between Versions

| Feature | Basic (v1.0) | Enhanced (v2.0) |
|---------|---------------|------------------|
| **Error Handling** | None | Comprehensive with exit codes |
| **Input Validation** | None | Timestamp validation |
| **Platform Check** | None | macOS compatibility check |
| **Debug Output** | None | Debug information available |
| **Uptime Calculation** | None | Detailed uptime reporting |
| **Timezone Support** | None | Timezone-aware output |
| **Logging** | None | Error logging to stderr |
| **Exit Codes** | Always 0 | Proper error exit codes |

## Technical Implementation

### Boot Time Retrieval

Both scripts use the same core method to retrieve boot time:
```bash
bootTime=$(sysctl kern.boottime | awk '{print $5}' | tr -d ',')
```

This command:
1. Uses `sysctl` to query kernel boot time
2. Extracts the timestamp using `awk`
3. Removes commas from the output

### Date Format Conversion

#### Basic Version (Simple)
```bash
prettyDate=$(date -jf %s "$bootTime" +%Y-%m-%dT%H:%M:%S)
```

#### Enhanced Version (Advanced)
```bash
prettyDate=$(date -jf %s "$bootTime" +%Y-%m-%dT%H:%M:%S%z 2>/dev/null)
```

The enhanced version includes timezone information (`%z`) and error handling.

### Output Format

Both scripts output in Jamf Pro Extension Attribute format:
```xml
<result>2025-01-15T14:30:25</result>
```

The enhanced version also provides uptime information:
```xml
<uptime>5d 12h 30m</uptime>
```

## Usage

### Jamf Pro Extension Attribute

#### Basic Version
1. **Upload Script**: Upload `lastReboot.sh` to Jamf Pro
2. **Create Extension Attribute**: 
   - Data Type: String
   - Input Type: Script
   - Script: Select the uploaded script
3. **Deploy**: Assign to appropriate smart groups

#### Enhanced Version
1. **Upload Script**: Upload `lastRebootEA.sh` to Jamf Pro
2. **Create Extension Attribute**:
   - Data Type: String
   - Input Type: Script
   - Script: Select the uploaded script
3. **Create Additional EA** (optional):
   - Data Type: String
   - Input Type: Script
   - Script: Modify to output only uptime information
4. **Deploy**: Assign to appropriate smart groups

### Manual Execution

#### Basic Version
```bash
# Make executable
chmod +x lastReboot.sh

# Run script
./lastReboot.sh
```

#### Enhanced Version
```bash
# Make executable
chmod +x lastRebootEA.sh

# Run script
./lastRebootEA.sh
```

### Expected Output

#### Basic Version
```
<result>2025-01-15T14:30:25</result>
```

#### Enhanced Version
```
<result>2025-01-15T14:30:25-0500</result>
<uptime>5d 12h 30m</uptime>
```

## Error Handling

### Basic Version
- No error handling
- May fail silently on errors
- Always returns exit code 0

### Enhanced Version
- **Platform Validation**: Ensures script runs on macOS
- **Input Validation**: Validates timestamp format
- **Error Logging**: Logs errors to stderr
- **Proper Exit Codes**: Returns appropriate exit codes
- **Graceful Degradation**: Handles conversion failures

### Error Scenarios Handled

1. **Non-macOS Platform**: Script exits with error message
2. **Invalid Boot Time**: Validates timestamp format
3. **Date Conversion Failure**: Handles conversion errors
4. **Missing System Commands**: Validates command availability

## Advanced Features (Enhanced Version)

### Uptime Calculation
The enhanced version calculates and reports system uptime:
```bash
uptime_seconds=$(($(date +%s) - bootTime))
uptime_days=$((uptime_seconds / 86400))
uptime_hours=$(((uptime_seconds % 86400) / 3600))
uptime_minutes=$(((uptime_seconds % 3600) / 60))
```

### Debug Mode
Includes debug output for troubleshooting:
```bash
echo "DEBUG: Extracted timestamp: $bootTime" >&2
```

### Strict Error Handling
Uses bash strict mode for better error detection:
```bash
set -euo pipefail
```

## Use Cases

### 1. System Monitoring
- **Uptime Tracking**: Monitor how long devices have been running
- **Stability Assessment**: Identify devices with long uptimes
- **Performance Monitoring**: Track system performance over time

### 2. Maintenance Management
- **Restart Scheduling**: Identify devices due for restarts
- **Patch Management**: Ensure devices restart after updates
- **Troubleshooting**: Identify devices that may need attention

### 3. Compliance and Reporting
- **Audit Requirements**: Track system uptime for compliance
- **Asset Management**: Monitor device usage patterns
- **Capacity Planning**: Understand device utilization

### 4. Jamf Pro Integration
- **Smart Groups**: Create groups based on uptime criteria
- **Policies**: Trigger actions based on uptime thresholds
- **Reporting**: Generate uptime reports for management

## Best Practices

### Deployment
1. **Test First**: Always test on a small group before full deployment
2. **Monitor Results**: Check Extension Attribute data after deployment
3. **Validate Output**: Ensure date formats are correct
4. **Set Thresholds**: Define acceptable uptime limits

### Smart Group Examples

#### Devices Needing Restart (>30 days)
```
Extension Attribute: lastReboot
Operator: greater than
Value: 30 days ago
```

#### Recently Restarted (<1 day)
```
Extension Attribute: lastReboot
Operator: less than
Value: 1 day ago
```

#### High Uptime Devices (>7 days)
```
Extension Attribute: uptime
Operator: greater than
Value: 7d
```

### Policy Integration
- **Scheduled Restarts**: Use uptime data to trigger restart policies
- **Maintenance Windows**: Schedule maintenance based on uptime
- **Alert Notifications**: Notify administrators of high uptime devices

## Troubleshooting

### Common Issues

1. **"Invalid boot time retrieved"**
   - System command failure
   - Corrupted system data
   - Permission issues

2. **"Failed to convert timestamp"**
   - Invalid timestamp format
   - Date command issues
   - System time problems

3. **Empty or incorrect output**
   - Script execution failure
   - Permission denied
   - Jamf Pro integration issues

### Debug Steps
1. **Check Script Permissions**: Ensure script is executable
2. **Test Manual Execution**: Run script directly on device
3. **Verify System Commands**: Check `sysctl` and `date` availability
4. **Review Jamf Pro Logs**: Check Extension Attribute execution logs
5. **Validate Output Format**: Ensure XML format is correct

### Log Locations
- **Jamf Pro**: Extension Attribute execution logs
- **System**: `/var/log/jamf.log` (if applicable)
- **Script**: Debug output to stderr (enhanced version)

## Security Considerations

### Permissions Required
- **Read Access**: System boot time information
- **Execution**: Script execution permissions
- **Network**: Jamf Pro communication (if applicable)

### Data Privacy
- **No Personal Data**: Only system information is collected
- **Minimal Impact**: Read-only operations only
- **Local Processing**: All processing occurs on device

## Future Enhancements

### Planned Improvements
- **Multiple Date Formats**: Support for different output formats
- **Uptime Thresholds**: Configurable uptime limits
- **Network Uptime**: Include network connectivity information
- **Historical Data**: Track uptime trends over time
- **Integration APIs**: Direct API integration with monitoring systems

### Compatibility Updates
- **New macOS Versions**: Support for upcoming releases
- **Jamf Pro Features**: Integration with new Jamf capabilities
- **Monitoring Tools**: Integration with enterprise monitoring systems

## Migration from Basic to Enhanced

### Recommended Steps
1. **Backup**: Document current Extension Attribute configuration
2. **Test**: Deploy enhanced version to test group
3. **Validate**: Confirm output format and accuracy
4. **Deploy**: Roll out to production devices
5. **Monitor**: Watch for any issues or errors

### Compatibility Notes
- Both versions use the same core boot time retrieval method
- Enhanced version is backward compatible
- Output format remains the same for basic functionality
- Additional uptime information is optional

---

*These scripts provide reliable system uptime monitoring for macOS devices in enterprise environments, enabling proactive maintenance and system management.*
