# jamfScripts

A collection of utility scripts for Jamf Pro and Oomnitza integration — focused on automating macOS device management tasks in enterprise environments.

> ⚠️ **Disclaimer:** These scripts are provided as-is without warranty of any kind. Always test in a non-production environment before deploying to production systems. Use at your own risk.

---

## Overview

These scripts extend Jamf Pro's functionality with additional automation and data collection capabilities, particularly useful for organizations managing macOS devices at scale.

---

## Scripts

### AppleCare Warranty Checker — JSON Version (`applecareWarranty.sh`)

**Version:** 2.0
**Last Updated:** August 21, 2025
**Compatibility:** macOS Ventura – Sequoia
**Status:** ✅ Recommended for all new deployments

Automatically retrieves AppleCare warranty information from Apple's local JSON cache and updates the device record in Jamf Pro.

#### Features

- Reads AppleCare warranty data from local JSON cache files
- Updates warranty expiration dates in Jamf Pro via API
- Supports multiple date formats (US and International)
- Includes fallback parsing via `jq` or `python3`
- Enhanced error handling and debug output

#### Prerequisites

- macOS device signed in with an Apple ID
- Enrolled in Jamf Pro
- AppleCare coverage information present on the device
- Jamf Pro API client with `Read Computers` and `Update Computers` permissions

#### Jamf Pro Script Parameters

| Parameter | Value |
|-----------|-------|
| 4 | Jamf Pro URL (e.g., `https://your-instance.jamfcloud.com`) |
| 5 | API Client ID |
| 6 | API Client Secret |

#### How It Works

1. Authenticates with Jamf Pro using OAuth (client credentials)
2. Retrieves the device serial number via `system_profiler`
3. Locates AppleCare warranty JSON files in the logged-in user's Library
4. Parses the warranty expiration date
5. Updates the computer inventory record in Jamf Pro

#### Warranty Cache File Location

```
/Users/{username}/Library/Application Support/com.apple.NewDeviceOutreach/caches/coverageDetails/
```

#### Dependencies

| Tool | Source |
|------|--------|
| `curl` | Built-in |
| `jq` | Preferred parser (install via Homebrew) |
| `python3` | Fallback parser (built-in on macOS) |
| `system_profiler` | Built-in |
| `xmllint` | Built-in |

---

### AppleCare Warranty Checker — Legacy PLIST Version (`getAppleCareWarrantyInfo.sh`)

**Version:** 1.0
**Last Updated:** December 31, 2024
**Compatibility:** macOS Ventura – Sequoia
**Status:** 🔶 Legacy — maintained for compatibility only

Reads AppleCare warranty information from `.plist` files and updates Jamf Pro. Use the JSON version (v2.0) for new deployments.

#### Features

- Reads warranty data from local plist files
- Updates warranty expiration dates in Jamf Pro via API
- Processes epoch timestamp format

#### Prerequisites

- macOS device signed in with an Apple ID
- Enrolled in Jamf Pro
- AppleCare coverage information present on the device
- Jamf Pro API client with `Read Computers` and `Update Computers` permissions

#### Configuration

Edit the following variables directly in the script before deploying:

```bash
JAMF_URL="https://your-instance.jamfcloud.com"
client_id="your-client-id"
client_secret="your-client-secret"
```

> 💡 Tip: Consider migrating these to Jamf Pro script parameters (Parameters 4–6) to match the v2.0 approach and avoid storing credentials in the script body.

#### Warranty Cache File Location

```
/Users/{username}/Library/Application Support/com.apple.NewDeviceOutreach/
```

#### Dependencies

| Tool | Source |
|------|--------|
| `curl` | Built-in |
| `PlistBuddy` | Built-in |
| `defaults` | Built-in |
| `system_profiler` | Built-in |
| `xmllint` | Built-in |

---

## Version Comparison

| | v1.0 (Legacy) | v2.0 (Current) |
|---|---|---|
| **File format** | `.plist` | `.json` |
| **Date format** | Epoch timestamp | Human-readable |
| **Credentials** | Hardcoded in script | Jamf script parameters |
| **Error handling** | Basic | Enhanced with debug output |
| **Recommended** | Legacy only | ✅ Yes |

---

## Installation

```bash
git clone https://github.com/your-username/jamfScripts.git
cd jamfScripts
chmod +x scripts/*.sh
```

---

## Jamf Pro API Setup

1. In Jamf Pro, navigate to **Settings > System > API Roles and Clients**
2. Create a new **API Role** with the following privileges:
   - `Read Computers`
   - `Update Computers`
3. Create a new **API Client** assigned to that role
4. Copy the **Client ID** and generate a **Client Secret**
5. Configure these as script parameters (Parameters 4–6) when deploying `applecareWarranty.sh`

> 🔒 Never hardcode credentials in scripts that will be stored in Jamf Pro or version control.

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Commit your changes: `git commit -m 'Description of change'`
4. Push and open a Pull Request

---

## Version History

| Version | Date | Notes |
|---------|------|-------|
| v2.0 | 2025-08-21 | JSON format, improved error handling, Jamf script parameters |
| v1.0 | 2024-12-31 | Initial release, PLIST format, epoch timestamp |

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Acknowledgments

- Original concept: [HCS Technology Group](https://hcsonline.com)
- Contributor: Scott Adamson, Oomnitza Inc.
