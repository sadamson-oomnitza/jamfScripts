# jamfScripts

A collection of utility scripts designed to enhance Jamf Pro and Oomnitza integration capabilities for macOS device management.

## Overview

This repository contains scripts that extend the functionality of Jamf Pro by providing additional automation and data collection capabilities. These scripts are particularly useful for organizations managing macOS devices in enterprise environments.

## Scripts

### AppleCare Warranty Checker - JSON Version (`applecareWarranty.sh`)

**Version:** 2.0  
**Last Updated:** August 21, 2025  
**Compatibility:** macOS Ventura - Sequoia  

Automatically retrieves and updates AppleCare warranty information in Jamf Pro by reading warranty data from Apple's local JSON cache files. This is the **recommended version** for current macOS systems.

#### Features
- Reads AppleCare warranty data from local JSON cache files
- Automatically updates warranty expiration dates in Jamf Pro
- Supports multiple date formats (US and International)
- Uses Jamf Pro API for secure data updates
- Includes fallback parsing methods (jq and Python3)
- Enhanced error handling and debugging output

#### Prerequisites
- macOS device signed in with an Apple ID
- Jamf Pro enrollment
- Device must have warranty coverage information available
- Jamf Pro API credentials with appropriate permissions

#### Usage

1. **Configure Jamf Pro Script Parameters:**
   - Parameter 4: Jamf Pro URL (e.g., `https://your-jamf-server.com`)
   - Parameter 5: Client ID
   - Parameter 6: Client Secret

2. **Deploy via Jamf Pro:**
   - Upload the script to Jamf Pro
   - Configure the required parameters
   - Deploy to target devices

#### How It Works

1. Authenticates with Jamf Pro using OAuth credentials
2. Retrieves the device's serial number
3. Locates AppleCare warranty JSON files in the user's Library
4. Parses warranty expiration information
5. Updates the warranty date in Jamf Pro's computer inventory

#### File Locations

The script reads warranty data from:
```
/Users/{username}/Library/Application Support/com.apple.NewDeviceOutreach/caches/coverageDetails/
```

#### Dependencies

- `curl` (built-in)
- `jq` (preferred) or `python3` (fallback)
- `system_profiler` (built-in)
- `xmllint` (built-in)

---

### AppleCare Warranty Checker - Legacy PLIST Version (`getAppleCareWarrantyInfo.sh`)

**Version:** 1.0  
**Last Updated:** December 31, 2024  
**Compatibility:** macOS Ventura - Sequoia  
**Status:** Legacy - Use JSON version for new deployments

Legacy version that reads AppleCare warranty information from `.plist` files. This version is maintained for compatibility with older systems but the JSON version is recommended for new deployments.

#### Features
- Reads AppleCare warranty data from local plist files
- Automatically updates warranty expiration dates in Jamf Pro
- Uses Jamf Pro API for secure data updates
- Processes epoch timestamp format

#### Prerequisites
- macOS device signed in with an Apple ID
- Jamf Pro enrollment
- Device must have warranty coverage information available
- Jamf Pro API credentials with appropriate permissions

#### Usage

1. **Configure Script Variables:**
   - Edit the script to set `JAMF_URL`, `client_id`, and `client_secret`
   - Or modify to use Jamf Pro script parameters

2. **Deploy via Jamf Pro:**
   - Upload the script to Jamf Pro
   - Deploy to target devices

#### How It Works

1. Authenticates with Jamf Pro using OAuth credentials
2. Retrieves the device's serial number
3. Locates AppleCare warranty plist files in the user's Library
4. Parses warranty expiration information from plist format
5. Updates the warranty date in Jamf Pro's computer inventory

#### File Locations

The script reads warranty data from:
```
/Users/{username}/Library/Application Support/com.apple.NewDeviceOutreach/
```

#### Dependencies

- `curl` (built-in)
- `PlistBuddy` (built-in)
- `defaults` (built-in)
- `system_profiler` (built-in)
- `xmllint` (built-in)

---

## Script Evolution

| Version | File Format | Date Format | Recommended Use |
|---------|-------------|-------------|-----------------|
| 2.0 | JSON | Human-readable | **Current - New deployments** |
| 1.0 | PLIST | Epoch timestamp | Legacy compatibility |

### Key Differences

- **File Format**: Version 1.0 uses `.plist` files, Version 2.0 uses `.json` files
- **Date Parsing**: Version 1.0 processes epoch timestamps, Version 2.0 handles human-readable dates
- **Error Handling**: Version 2.0 includes enhanced error handling and debugging
- **Flexibility**: Version 2.0 supports multiple date formats and parsing methods

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/your-username/jamfScripts.git
   cd jamfScripts
   ```

2. Review and customize scripts as needed for your environment

3. Upload scripts to your Jamf Pro instance

## Configuration

### Jamf Pro API Setup

1. Create an API client in Jamf Pro:
   - Navigate to **Settings** > **System Settings** > **Jamf Pro User Accounts & Groups**
   - Create a new API client with appropriate permissions

2. Configure script parameters in Jamf Pro:
   - Set the required parameters (URL, Client ID, Client Secret)
   - Ensure the API client has permissions to read and update computer inventory

### Script Permissions

Ensure scripts have appropriate execution permissions:
```bash
chmod +x scripts/*.sh
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support and questions:
- **HCS Technology Group:** info@hcsonline.com
- **Website:** https://hcsonline.com

## Acknowledgments

- **Original Author:** HCS Technology Group
- **Contributors:** Scott Adamson (Oomnitza Inc)
- **AI Assistance:** Claude

## Disclaimer

⚠️ **IMPORTANT:** These scripts are provided as-is without warranty of any kind. Use them at your own risk. Always test scripts in a non-production environment before deploying to production systems.

## Version History

### AppleCare Warranty Checker
- **v2.0** (2025-08-21): Updated for new Apple JSON format, improved error handling, enhanced date parsing
- **v1.0** (2024-12-31): Initial release with PLIST parsing and epoch timestamp support

---

**Note:** This repository is actively maintained and updated to support the latest macOS versions and Jamf Pro features. The JSON version (v2.0) is recommended for all new deployments.
