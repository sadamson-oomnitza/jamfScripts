#!/bin/sh

# Jamf Connect App location (both 2.x and 3.x use same location)
jamfConnectLocation="/Applications/Jamf Connect.app"

# Jamf Self Service and Plus location
jamfSelfServiceLocation="/Applications/Self Service.app"
jamfSelfServicePlusLocation="/Applications/Self Service+.app"

# Check for Jamf Connect version
if [ -d "$jamfConnectLocation" ]; then
    jamfConnectVersion=$(defaults read "$jamfConnectLocation"/Contents/Info.plist "CFBundleShortVersionString" 2>/dev/null || echo "Unable to read version")
else
    jamfConnectVersion="Not installed"
fi

# Check for Jamf Self Service version (prioritize Self Service+ if both exist)
if [ -d "$jamfSelfServicePlusLocation" ]; then
    jamfSelfServiceVersion=$(defaults read "$jamfSelfServicePlusLocation"/Contents/Info.plist "CFBundleShortVersionString" 2>/dev/null || echo "Unable to read version")
elif [ -d "$jamfSelfServiceLocation" ]; then
    jamfSelfServiceVersion=$(defaults read "$jamfSelfServiceLocation"/Contents/Info.plist "CFBundleShortVersionString" 2>/dev/null || echo "Unable to read version")
else
    jamfSelfServiceVersion="Not installed"
fi

echo "jamfConnectVersion"
echo "<result>$jamfConnectVersion</result>"
echo "jamfSelfServiceVersion"
echo "<result>$jamfSelfServiceVersion</result>"