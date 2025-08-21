# Mac Computer Naming Script Documentation

## Overview

The Mac Computer Naming Scripts provide automated computer naming functionality for macOS devices in enterprise environments. These scripts automatically generate and set computer names based on hardware information, following a consistent naming convention.

## Script Versions

### Current Version: `nameComputerScript.sh` (v2.0)
**Last Updated:** 2025  
**Compatibility:** macOS Ventura - Sequoia  

Enhanced version with improved error handling, latest Mac model support, and comprehensive logging.

### Legacy Version: `nameComputer.sh` (v1.0)
**Last Updated:** 2024  
**Compatibility:** macOS Ventura - Sequoia  
**Status:** Legacy - Use new version for deployments

Original version with basic functionality and limited model support.

## Naming Convention

Both scripts follow the same naming convention:
```
{SerialNumber}-{DeviceType}-{ChipType}
```

### Examples:
- `C02XYZ123ABC-MBP-M3` (MacBook Pro with M3 chip)
- `C02XYZ456DEF-MBA-M2` (MacBook Air with M2 chip)
- `C02XYZ789GHI-iMac-Intel` (iMac with Intel processor)

## Key Differences Between Versions

| Feature | Legacy (v1.0) | Current (v2.0) |
|---------|---------------|----------------|
| **Error Handling** | Basic | Comprehensive with logging |
| **Model Support** | Limited 2024 models | Extended 2025+ models |
| **Hardware Detection** | Single method | Multiple fallback methods |
| **Chip Detection** | Basic Apple Silicon/Intel | Detailed M1-M6 detection |
| **Validation** | Minimal | Extensive name validation |
| **Logging** | Basic file logging | Structured logging with timestamps |
| **Jamf Integration** | Single path check | Multiple path detection |
| **Future Proofing** | No | M5/M6 chip support included |

## Technical Implementation

### Hardware Information Extraction

#### Current Version (Enhanced)
```bash
# Multiple fallback methods for serial number
result=$(system_profiler SPHardwareDataType | awk -F": " '/Serial Number/{print $2}' | tr -d ' ')
if [ -z "$result" ]; then
    result=$(ioreg -l | grep IOPlatformSerialNumber | awk -F'"' '{print $4}')
fi
if [ -z "$result" ]; then
    result=$(sysctl -n hw.serialno 2>/dev/null)
fi
```

#### Legacy Version (Basic)
```bash
# Single method only
serialNumber=$(system_profiler SPHardwareDataType | awk -F": " '/Serial Number/{print $2}' | tr -d ' ')
```

### Device Type Mapping

#### Current Version (Extended)
Supports latest 2025 models including:
- **M4 MacBook Air/Pro** models
- **Future M5 models** (expected 2026)
- **Enhanced Mac Studio/Pro** support
- **Improved fallback handling**

#### Legacy Version (Limited)
Basic model support for 2024 and earlier models.

### Chip Type Detection

#### Current Version (Comprehensive)
```bash
case "$chipType" in
    *"M1"*) chipType="M1" ;;
    *"M2"*) chipType="M2" ;;
    *"M3"*) chipType="M3" ;;
    *"M4"*) chipType="M4" ;;
    *"M5"*) chipType="M5" ;; # Future proofing
    *"M6"*) chipType="M6" ;; # Future proofing
    *"Apple"*) chipType="AS" ;; # Generic Apple Silicon
    *"Intel"*) chipType="Intel" ;;
    *"Core"*) chipType="Intel" ;;
    *) chipType="Unknown" ;;
esac
```

#### Legacy Version (Basic)
```bash
if [ -z "$chipType" ]; then
    chipType=$(system_profiler SPHardwareDataType | awk -F": " '/Processor Name/{print $2}' | tr -d ' ')
    if [ -z "$chipType" ]; then
        chipType="Intel"
    fi
fi
```

## Usage

### Deployment via Jamf Pro

1. **Upload Script**: Upload the appropriate script version to Jamf Pro
2. **Configure Policy**: Create a policy to run the script
3. **Set Scope**: Target devices that need naming updates
4. **Execute**: Run the policy to apply computer names

### Manual Execution

```bash
# Make script executable
chmod +x nameComputerScript.sh

# Run with sudo (required for system changes)
sudo ./nameComputerScript.sh
```

### Script Parameters

Both scripts are self-contained and require no parameters. They automatically:
- Detect hardware information
- Generate appropriate names
- Set system computer names
- Update Jamf Pro (if available)

## System Changes Made

### Computer Name Settings
The scripts modify three system properties:
1. **ComputerName**: User-visible computer name
2. **HostName**: Network hostname
3. **LocalHostName**: Bonjour/mDNS name (sanitized)

### Jamf Pro Integration
- Updates Jamf Pro computer name if Jamf binary is available
- Supports multiple Jamf binary locations
- Provides error handling for Jamf operations

## Logging and Monitoring

### Current Version Logging
```bash
# Structured logging with timestamps
log_message() {
    local message="$1"
    local logFile="/var/log/computerNameScript.log"
    mkdir -p "$(dirname "$logFile")"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $message" | tee -a "$logFile"
}
```

### Log File Location
- **Path**: `/var/log/computerNameScript.log`
- **Format**: Timestamped entries with detailed information
- **Content**: Hardware detection, name generation, system changes, verification

### Monitoring Recommendations
1. **Review logs** after deployment to ensure successful execution
2. **Monitor for errors** in hardware detection or name setting
3. **Verify naming consistency** across the fleet
4. **Check Jamf Pro integration** success rates

## Error Handling

### Current Version (Comprehensive)
- **Hardware detection failures**: Multiple fallback methods
- **Name validation**: Length checking and truncation
- **System command failures**: Error checking and logging
- **Jamf integration failures**: Graceful degradation
- **Unknown hardware**: Fallback to generic names

### Legacy Version (Basic)
- **Limited error handling**: Basic failure detection
- **No validation**: Minimal input checking
- **Simple logging**: Basic file output

## Supported Hardware

### Device Types
- **MacBook Air** (MBA)
- **MacBook Pro** (MBP)
- **iMac** (iMac)
- **Mac mini** (Mini)
- **Mac Studio** (Studio)
- **Mac Pro** (Pro)

### Chip Types
- **Apple Silicon**: M1, M2, M3, M4, M5, M6
- **Intel**: Intel, Core processors
- **Generic**: AS (Apple Silicon), Unknown

### Model Identifiers
The current version supports extensive model identifier mapping including:
- Legacy Intel models
- Current Apple Silicon models
- Future M4/M5 models (future-proofing)

## Best Practices

### Deployment
1. **Test First**: Always test on a small group before full deployment
2. **Backup Names**: Document existing names before running
3. **Staged Rollout**: Deploy to test groups before production
4. **Monitor Results**: Review logs and verify naming consistency

### Maintenance
1. **Regular Updates**: Keep script updated for new hardware
2. **Model Mapping**: Update device type mappings as needed
3. **Chip Detection**: Enhance chip detection for new processors
4. **Log Rotation**: Implement log rotation for long-term deployments

### Troubleshooting
1. **Check Logs**: Review `/var/log/computerNameScript.log`
2. **Verify Hardware**: Confirm hardware detection accuracy
3. **Test Permissions**: Ensure script has required sudo access
4. **Jamf Integration**: Verify Jamf binary availability and permissions

## Migration from Legacy to Current Version

### Recommended Steps
1. **Backup**: Document current naming scheme
2. **Test**: Deploy new version to test devices
3. **Validate**: Confirm naming consistency
4. **Deploy**: Roll out to production devices
5. **Monitor**: Watch logs for any issues

### Compatibility Notes
- Both versions use the same naming convention
- New version is backward compatible
- Enhanced error handling prevents failures
- Improved logging aids troubleshooting

## Security Considerations

### Permissions Required
- **sudo access**: Required for system name changes
- **Jamf integration**: Requires Jamf binary access
- **Log writing**: Requires write access to `/var/log/`

### Data Privacy
- **No personal data**: Only hardware information is processed
- **Local execution**: All processing occurs on the device
- **Minimal logging**: Only technical information is logged

## Future Enhancements

### Planned Improvements
- **Network validation**: Check for naming conflicts
- **Custom naming schemes**: Support for organization-specific formats
- **API integration**: Direct Jamf Pro API updates
- **Configuration files**: External configuration support
- **GUI interface**: Optional graphical interface

### Compatibility Updates
- **New hardware**: Support for future Mac models
- **macOS versions**: Compatibility with upcoming releases
- **Jamf Pro versions**: Support for new Jamf features

---

*These scripts provide reliable, automated computer naming for macOS devices in enterprise environments, ensuring consistent naming conventions and reducing manual administration overhead.*
