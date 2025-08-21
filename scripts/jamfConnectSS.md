# Jamf Connect and Self Service Version Check Documentation

## Overview

The Jamf Connect and Self Service Version Check Script (`jamfConnectSS.sh`) is a comprehensive bash script designed to check and report the installed and running versions of Jamf Connect and Self Service applications. This script is optimized for use with Jamf Pro Extension Attributes to provide version management and compliance monitoring capabilities.

## Purpose

This script serves several important functions in enterprise macOS management:

1. **Version Compliance**: Monitor Jamf Connect and Self Service version compliance
2. **Application Status**: Check if applications are installed and running
3. **Update Management**: Identify devices needing updates to latest versions
4. **Troubleshooting**: Provide detailed application status for support
5. **Inventory Management**: Track application versions across the fleet

## Features

### Core Functionality
- **Version Detection**: Checks installed versions of Jamf Connect and Self Service
- **Running Status**: Determines if applications are currently running
- **Version Comparison**: Compares installed versions against latest versions
- **Status Indicators**: Provides visual status indicators (✅❌⚠️ℹ️)
- **Comprehensive Logging**: Detailed logging for troubleshooting

### Advanced Features
- **Latest Version Tracking**: Configurable latest version constants
- **Self Service+ Support**: Prioritizes Self Service+ over standard Self Service
- **Bundle ID Detection**: Identifies application bundle identifiers
- **Error Handling**: Comprehensive error handling with proper exit codes
- **Platform Validation**: Ensures script runs on macOS only

## Technical Implementation

### Latest Version Constants
```bash
LATEST_JAMF_CONNECT_VERSION="3.2"
LATEST_SELF_SERVICE_VERSION="2.7"
```

These constants define the latest versions for comparison.

### Application Detection

#### Jamf Connect Detection
```bash
if [[ -d "$jamfConnectLocation" ]]; then
    jamfConnectVersion=$(defaults read "$jamfConnectLocation"/Contents/Info.plist "CFBundleShortVersionString" 2>/dev/null || echo "Unable to read version")
    jamfConnectBundleID=$(defaults read "$jamfConnectLocation"/Contents/Info.plist "CFBundleIdentifier" 2>/dev/null || echo "com.jamf.connect")
    jamfConnectRunning=$(check_app_running "Jamf Connect" "$jamfConnectBundleID")
    jamfConnectStatus=$(compare_versions "$jamfConnectVersion" "$LATEST_JAMF_CONNECT_VERSION")
fi
```

#### Self Service Detection (Prioritizes Self Service+)
```bash
if [[ -d "$jamfSelfServicePlusLocation" ]]; then
    # Check Self Service+ first
    jamfSelfServiceType="Self Service+"
elif [[ -d "$jamfSelfServiceLocation" ]]; then
    # Fall back to standard Self Service
    jamfSelfServiceType="Self Service"
else
    jamfSelfServiceType="Not installed"
fi
```

### Version Comparison Logic
```bash
compare_versions() {
    local installed_version="$1"
    local latest_version="$2"
    
    if [[ "$installed_version" == "Not installed" ]] || [[ "$installed_version" == "Unable to read version" ]]; then
        echo "Unknown"
    elif [[ "$installed_version" == "$latest_version" ]]; then
        echo "Latest"
    elif [[ "$installed_version" > "$latest_version" ]]; then
        echo "Newer"
    else
        echo "Outdated"
    fi
}
```

### Running Status Detection
```bash
check_app_running() {
    local app_name="$1"
    local bundle_id="$2"
    
    if pgrep -f "$bundle_id" >/dev/null 2>&1; then
        echo "Running"
    else
        echo "Not Running"
    fi
}
```

## Output Format

### Jamf Pro Extension Attribute Format

#### Both Applications Latest
```xml
<result>✅ Jamf Connect 3.2 (Latest) | Self Service+ 2.7 (Latest)</result>
```

#### Neither Installed
```xml
<result>❌ Jamf Connect: Not Installed | Self Service: Not Installed</result>
```

#### Outdated Applications
```xml
<result>⚠️ Jamf Connect 3.1 (Outdated) | Self Service+ 2.6 (Outdated)</result>
```

#### Mixed Status
```xml
<result>ℹ️ Jamf Connect 3.2 (Latest) | Self Service+ 2.6 (Outdated)</result>
```

### Detailed Output
```xml
<details>
Jamf Connect:
  Version: 3.2
  Status: Latest (Latest: 3.2)
  Running: Running
  Location: /Applications/Jamf Connect.app

Self Service:
  Type: Self Service+
  Version: 2.7
  Status: Latest (Latest: 2.7)
  Running: Running
  Location: /Applications/Self Service+.app
  Bundle ID: com.jamf.selfservice
</details>
```

## Usage

### Jamf Pro Extension Attribute

1. **Upload Script**: Upload `jamfConnectSS.sh` to Jamf Pro
2. **Create Extension Attribute**:
   - Data Type: String
   - Input Type: Script
   - Script: Select the uploaded script
3. **Deploy**: Assign to appropriate smart groups

### Manual Execution

```bash
# Make executable
chmod +x jamfConnectSS.sh

# Run script
./jamfConnectSS.sh
```

### Expected Output

#### Successful Check
```
<result>✅ Jamf Connect 3.2 (Latest) | Self Service+ 2.7 (Latest)</result>
```

#### Outdated Applications
```
<result>⚠️ Jamf Connect 3.1 (Outdated) | Self Service+ 2.6 (Outdated)</result>
```

## Dependencies

### Required
- **defaults**: For reading application Info.plist files
- **pgrep**: For checking running processes
- **bash**: Script execution environment

### System Requirements
- **macOS**: Designed for macOS systems
- **Application Access**: Requires access to application directories
- **Permissions**: May require permissions to read application metadata

## Error Handling

### Version Reading Failures
- **Graceful Degradation**: Handles cases where version cannot be read
- **Fallback Values**: Provides default values for missing information
- **Error Logging**: Logs errors for troubleshooting

### Application Detection
- **Multiple Locations**: Checks both Self Service and Self Service+
- **Bundle ID Fallback**: Uses default bundle IDs if not found
- **Status Validation**: Validates application status

### Logging
- **Log File**: Adaptive log location based on permissions
  - Primary: `/var/log/jamfConnectSS.log`
  - Fallback: `$HOME/Library/Logs/jamfConnectSS.log`
  - Final fallback: `/tmp/jamfConnectSS.log`
- **Permission Handling**: Graceful fallback when write permissions denied
- **Timestamped Entries**: All operations logged with timestamps
- **Error Logging**: Errors logged to both stderr and log file
- **Debug Information**: Detailed logging for troubleshooting

## Use Cases

### 1. Version Management
- **Update Compliance**: Ensure devices have latest versions
- **Rollout Tracking**: Monitor version deployment progress
- **Version Inventory**: Track application versions across fleet
- **Update Planning**: Identify devices needing updates

### 2. Application Monitoring
- **Installation Status**: Verify applications are properly installed
- **Running Status**: Monitor application availability
- **Health Checks**: Ensure applications are functioning
- **Troubleshooting**: Provide status information for support

### 3. Jamf Pro Integration
- **Smart Groups**: Create groups based on version status
- **Policies**: Trigger update policies based on version
- **Reporting**: Generate version compliance reports
- **Alerting**: Set up alerts for outdated versions

### 4. Compliance and Auditing
- **Version Compliance**: Ensure compliance with version requirements
- **Audit Support**: Provide version data for audits
- **Policy Enforcement**: Enforce version policies
- **Documentation**: Document application versions

## Best Practices

### Deployment
1. **Test First**: Always test on a small group before full deployment
2. **Monitor Logs**: Review script logs after deployment
3. **Validate Output**: Ensure version detection is accurate
4. **Update Constants**: Keep latest version constants current

### Smart Group Examples

#### Latest Versions
```
Extension Attribute: jamfConnectSS
Operator: contains
Value: "✅"
```

#### Outdated Applications
```
Extension Attribute: jamfConnectSS
Operator: contains
Value: "⚠️"
```

#### Not Installed
```
Extension Attribute: jamfConnectSS
Operator: contains
Value: "❌"
```

#### Jamf Connect Outdated
```
Extension Attribute: jamfConnectSS
Operator: contains
Value: "Jamf Connect.*Outdated"
```

#### Self Service Outdated
```
Extension Attribute: jamfConnectSS
Operator: contains
Value: "Self Service.*Outdated"
```

### Policy Integration
- **Update Policies**: Trigger updates for outdated applications
- **Installation Policies**: Install missing applications
- **Compliance Policies**: Enforce version requirements
- **Monitoring Policies**: Regular version checks

## Troubleshooting

### Common Issues

1. **"Unable to read version"**
   - Application Info.plist corruption
   - Permission issues
   - Application installation problems

2. **"Not Running" status**
   - Application not launched
   - Process termination
   - System resource issues

3. **"Unknown" status**
   - Version reading failure
   - Application metadata issues
   - File system problems

4. **Incorrect version detection**
   - Multiple application versions
   - Installation location issues
   - Bundle ID conflicts

### Debug Steps
1. **Check Script Permissions**: Ensure script is executable
2. **Test Manual Execution**: Run script directly on device
3. **Verify Application Installation**: Check application directories
4. **Review Script Logs**: Check log file location (script will report this)
5. **Validate Info.plist**: Check application metadata files

### Log Analysis
```bash
# View recent log entries (check actual log location first)
tail -f /var/log/jamfConnectSS.log
# or
tail -f ~/Library/Logs/jamfConnectSS.log
# or
tail -f /tmp/jamfConnectSS.log

# Search for errors
grep "ERROR" /var/log/jamfConnectSS.log

# Check successful executions
grep "completed successfully" /var/log/jamfConnectSS.log
```

## Security Considerations

### Permissions Required
- **Read Access**: Application directory and metadata access
- **Process Access**: Ability to check running processes
- **Execution**: Script execution permissions

### Data Privacy
- **No Personal Data**: Only application version information
- **Minimal Logging**: Only technical information logged
- **Local Processing**: All processing occurs on device

### Compliance
- **Version Tracking**: Supports compliance requirements
- **Audit Support**: Provides version data for audits
- **Policy Enforcement**: Enables version policy enforcement

## Limitations

### Version Detection
- **Info.plist Dependency**: Relies on application Info.plist files
- **Installation Location**: Assumes standard installation locations
- **Bundle ID Dependency**: Requires correct bundle identifiers

### Running Status
- **Process Detection**: May not detect all running instances
- **Timing Issues**: Status may change between checks
- **Background Processes**: May not detect background processes

### Version Comparison
- **String Comparison**: Uses string comparison for version checking
- **Format Dependency**: Assumes standard version format
- **Latest Version Maintenance**: Requires manual updates to latest version constants

## Future Enhancements

### Planned Improvements
- **Multiple Version Sources**: Check additional version sources
- **Automatic Latest Version Detection**: Fetch latest versions automatically
- **Historical Tracking**: Track version changes over time
- **Integration APIs**: Direct integration with Jamf Pro APIs

### Compatibility Updates
- **New Application Versions**: Support for future versions
- **macOS Compatibility**: Support for new macOS releases
- **Application Changes**: Adapt to application structure changes

---

*This script provides reliable version monitoring for Jamf Connect and Self Service applications in enterprise environments, enabling effective version management and compliance monitoring.*
