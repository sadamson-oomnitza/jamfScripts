# Privilege Elevation Count Extension Attribute Documentation

## Overview

The Privilege Elevation Count Extension Attribute (`privilegeElevationsEA.sh`) is a sophisticated bash script designed to count and report privilege escalations that have occurred on macOS devices in the last 24 hours. This script is optimized for use with Jamf Pro Extension Attributes to provide security monitoring and compliance reporting capabilities.

## Purpose

This script serves several important functions in enterprise macOS security management:

1. **Security Monitoring**: Track privilege escalation attempts and usage
2. **Compliance Reporting**: Monitor administrative access for audit requirements
3. **Threat Detection**: Identify unusual privilege escalation patterns
4. **User Behavior Analysis**: Understand how users interact with elevated privileges
5. **Incident Response**: Provide data for security incident investigations

## Features

### Core Functionality
- **24-Hour Window**: Counts privilege escalations in the last 24 hours
- **Multiple Sources**: Monitors Jamf Connect, sudo, authd, and other privilege events
- **Detailed Breakdown**: Provides counts by privilege escalation type
- **Recent Examples**: Includes recent event examples for context
- **Comprehensive Logging**: Detailed logging for troubleshooting

### Advanced Features
- **Error Handling**: Comprehensive error handling with proper exit codes
- **Timeout Protection**: Prevents hanging on log queries
- **Platform Validation**: Ensures script runs on macOS only
- **Performance Optimization**: Efficient log querying and processing
- **Detailed Output**: Both summary and detailed information

## Technical Implementation

### Time Range Calculation
```bash
start_time=$(date -v-24H '+%Y-%m-%d %H:%M:%S')
current_time=$(date '+%Y-%m-%d %H:%M:%S')
```

The script calculates a rolling 24-hour window from the current time.

### Privilege Escalation Detection

#### Jamf Connect Events
```bash
jamf_events=$(timeout 15 log show \
    --predicate '(process == "Jamf Connect" AND (eventMessage CONTAINS "privilege" OR eventMessage CONTAINS "admin" OR eventMessage CONTAINS "TemporaryAdmin"))' \
    --start "$start_time" \
    --style compact \
    --info \
    2>/dev/null)
```

#### Sudo Events
```bash
sudo_events=$(timeout 15 log show \
    --predicate '(process == "sudo" AND NOT eventMessage CONTAINS "libsystem_info")' \
    --start "$start_time" \
    --style compact \
    --info \
    2>/dev/null)
```

#### Authd Events
```bash
authd_events=$(timeout 15 log show \
    --predicate '(process == "authd" AND eventMessage CONTAINS "authenticated" AND (eventMessage CONTAINS "admin" OR eventMessage CONTAINS "sudo"))' \
    --start "$start_time" \
    --style compact \
    --info \
    2>/dev/null)
```

#### Other Privilege Events
```bash
other_events=$(timeout 15 log show \
    --predicate '(eventMessage CONTAINS "privilege" OR eventMessage CONTAINS "admin" OR eventMessage CONTAINS "elevation") AND NOT (process == "Jamf Connect" OR process == "sudo" OR process == "authd")' \
    --start "$start_time" \
    --style compact \
    --info \
    2>/dev/null)
```

### Output Format

#### Jamf Pro Extension Attribute Format
```xml
<result>15 (J:8,S:5,A:2) - Recent: [JAMF] User granted temporary admin | [SUDO] User executed command</result>
```

#### Detailed Output
```xml
<details>
Time Range: 2025-01-14 10:30:00 to 2025-01-15 10:30:00
Total Count: 15
Jamf Connect: 8
Sudo: 5
Authd: 2
Other: 0
Breakdown: J:8,S:5,A:2
</details>
```

## Usage

### Jamf Pro Extension Attribute

1. **Upload Script**: Upload `privilegeElevationsEA.sh` to Jamf Pro
2. **Create Extension Attribute**:
   - Data Type: String
   - Input Type: Script
   - Script: Select the uploaded script
3. **Deploy**: Assign to appropriate smart groups

### Manual Execution

```bash
# Make executable
chmod +x privilegeElevationsEA.sh

# Run script
./privilegeElevationsEA.sh
```

### Expected Output

#### With Privilege Escalations
```
<result>12 (J:5,S:4,A:3) - Recent: [JAMF] User granted temporary admin | [SUDO] User executed command</result>
```

#### No Privilege Escalations
```
<result>0 (No privilege escalations in last 24 hours)</result>
```

## Dependencies

### Required
- **log**: macOS unified logging system
- **bash**: Script execution environment
- **timeout**: For preventing hanging queries

### System Requirements
- **macOS**: Designed for macOS systems with unified logging
- **Log Access**: Requires access to system logs
- **Permissions**: May require elevated permissions for log access

## Error Handling

### Timeout Protection
- **15-second timeout**: Prevents hanging on log queries
- **Graceful degradation**: Continues with available data
- **Error logging**: Logs timeout events for troubleshooting

### Data Validation
- **Empty result handling**: Handles cases with no privilege events
- **Count validation**: Ensures numeric counts are valid
- **Output sanitization**: Cleans and formats output properly

### Logging
- **Log File**: `/var/log/privilegeElevationsEA.log`
- **Timestamped Entries**: All operations logged with timestamps
- **Error Logging**: Errors logged to both stderr and log file
- **Debug Information**: Detailed logging for troubleshooting

## Use Cases

### 1. Security Monitoring
- **Privilege Escalation Tracking**: Monitor administrative access patterns
- **Anomaly Detection**: Identify unusual privilege escalation activity
- **Threat Hunting**: Detect potential security threats
- **User Behavior Analysis**: Understand privilege usage patterns

### 2. Compliance and Auditing
- **Administrative Access Audits**: Track who uses elevated privileges
- **Compliance Reporting**: Generate reports for regulatory requirements
- **Policy Enforcement**: Monitor compliance with privilege policies
- **Incident Documentation**: Document privilege escalation events

### 3. Jamf Pro Integration
- **Smart Groups**: Create groups based on privilege escalation counts
- **Policies**: Trigger actions based on privilege escalation thresholds
- **Reporting**: Generate privilege escalation reports for management
- **Alerting**: Set up alerts for high privilege escalation counts

### 4. Incident Response
- **Security Investigations**: Provide data for security incident analysis
- **Forensic Analysis**: Track privilege escalation timeline
- **User Accountability**: Identify users with elevated privileges
- **System Monitoring**: Monitor system security posture

## Best Practices

### Deployment
1. **Test First**: Always test on a small group before full deployment
2. **Monitor Logs**: Review script logs after deployment
3. **Validate Output**: Ensure privilege escalation data is accurate
4. **Set Thresholds**: Define acceptable privilege escalation limits

### Smart Group Examples

#### High Privilege Escalation Count (>10 in 24h)
```
Extension Attribute: privilegeElevationsEA
Operator: contains
Value: "1[0-9]|2[0-9]|3[0-9]"
```

#### No Privilege Escalations
```
Extension Attribute: privilegeElevationsEA
Operator: contains
Value: "0 (No privilege escalations"
```

#### Jamf Connect Privilege Escalations
```
Extension Attribute: privilegeElevationsEA
Operator: contains
Value: "J:[1-9]"
```

#### Sudo Privilege Escalations
```
Extension Attribute: privilegeElevationsEA
Operator: contains
Value: "S:[1-9]"
```

### Policy Integration
- **High Count Alerts**: Trigger alerts for excessive privilege escalations
- **Security Policies**: Restrict access based on privilege escalation patterns
- **Compliance Policies**: Enforce privilege escalation policies
- **Monitoring Policies**: Regular privilege escalation monitoring

## Troubleshooting

### Common Issues

1. **"No privilege events detected"**
   - No privilege escalations in the time window
   - Log access permissions
   - System logging configuration

2. **"Timeout" errors**
   - Large log files causing slow queries
   - System performance issues
   - Network connectivity problems

3. **"Permission denied" errors**
   - Insufficient permissions for log access
   - SIP (System Integrity Protection) restrictions
   - File system permissions

4. **Empty or incorrect output**
   - Script execution failure
   - Log query syntax issues
   - Output formatting problems

### Debug Steps
1. **Check Script Permissions**: Ensure script is executable
2. **Test Manual Execution**: Run script directly on device
3. **Verify Log Access**: Test log show command manually
4. **Review Script Logs**: Check `/var/log/privilegeElevationsEA.log`
5. **Validate Time Range**: Confirm 24-hour window calculation

### Log Analysis
```bash
# View recent log entries
tail -f /var/log/privilegeElevationsEA.log

# Search for errors
grep "ERROR" /var/log/privilegeElevationsEA.log

# Check successful executions
grep "completed successfully" /var/log/privilegeElevationsEA.log
```

## Security Considerations

### Permissions Required
- **Log Access**: Read access to system logs
- **Execution**: Script execution permissions
- **File System**: Write access to log directory

### Data Privacy
- **No Personal Data**: Only privilege escalation counts and types
- **Minimal Logging**: Only technical information logged
- **Local Processing**: All processing occurs on device

### Compliance
- **Audit Trail**: Provides audit trail for administrative access
- **Regulatory Support**: Supports compliance requirements
- **Data Retention**: Logs retained for security purposes

## Limitations

### Log Availability
- **Log Retention**: Depends on system log retention policies
- **Log Size**: Large logs may affect query performance
- **Log Access**: May be restricted by system policies

### Detection Accuracy
- **Time Window**: Only captures events in last 24 hours
- **Log Coverage**: Depends on system logging configuration
- **Event Types**: Limited to detected privilege escalation types

### Performance Impact
- **Query Time**: Log queries may take time on systems with large logs
- **System Resources**: May impact system performance during execution
- **Network Dependencies**: No network dependencies

## Future Enhancements

### Planned Improvements
- **Configurable Time Windows**: Support for different time ranges
- **Additional Event Types**: Support for more privilege escalation sources
- **Historical Tracking**: Track privilege escalation trends over time
- **Integration APIs**: Direct integration with security monitoring systems

### Compatibility Updates
- **New macOS Versions**: Support for upcoming releases
- **Jamf Pro Features**: Integration with new Jamf capabilities
- **Log Format Changes**: Adapt to system log format changes

---

*This script provides reliable privilege escalation monitoring for macOS devices in enterprise environments, enabling security monitoring and compliance reporting.*
