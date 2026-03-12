#!/bin/bash
#######################################################################
#
# Remove Application Script for Jamf Pro
#
# Deletes sandboxed apps from /Applications and optionally removes
# app support files and forgets associated packages.
#
# Parameters:
#   $4 - App name (e.g., "TeamViewer") or full path (e.g., "/Applications/TeamViewer.app")
#   $5 - App Support path to remove (optional)
#   $6+ - Package bundle IDs (partial match) to forget via pkgutil (optional)
#
#######################################################################

appName="$4"
appSupport="$5"

function silent_app_quit() {
    local appName="$1"

    if pgrep -ix "$appName" &>/dev/null; then
        echo "Closing $appName..."
        /usr/bin/osascript -e "quit app \"$appName\""
        sleep 1

        local countUp=0
        while [[ $countUp -le 10 ]]; do
            if ! pgrep -ix "$appName" &>/dev/null; then
                echo "$appName closed successfully."
                return 0
            fi
            ((countUp++))
            sleep 1
        done

        echo "$appName did not quit gracefully — force killing."
        /usr/bin/pkill -ix "$appName"
    else
        echo "$appName is not running."
    fi
}

# Validate input
if [[ -z "$appName" ]]; then
    echo "ERROR: No application name specified. Exiting."
    exit 1
fi

# Quit app if running
silent_app_quit "$appName"

echo "Removing application: $appName"

# Append .app extension if not present
if [[ "$appName" != *".app"* ]]; then
    appName="${appName}.app"
fi

# Build full path if only a name was given
if [[ "$appName" != *"/"* ]]; then
    appToDelete="/Applications/$appName"
else
    appToDelete="$appName"
fi

# Remove the application bundle
if [[ -e "$appToDelete" ]]; then
    /bin/rm -rf "$appToDelete"
    if [[ ! -e "$appToDelete" ]]; then
        echo "SUCCESS: $appName has been removed."
    else
        echo "ERROR: $appName could not be removed."
        exit 1
    fi
else
    echo "WARNING: $appName not found at $appToDelete — nothing to remove."
fi

# Remove App Support files if specified
if [[ -n "$appSupport" ]]; then
    if [[ -e "$appSupport" ]]; then
        echo "Removing App Support path: $appSupport"
        /bin/rm -rf "$appSupport"
        echo "App Support removed."
    else
        echo "WARNING: App Support path not found: $appSupport"
    fi
fi

# Forget packages matching provided bundle ID fragments ($6 onward)
for package in "${@:6}"; do
    if [[ -n "$package" ]]; then
        echo "Forgetting packages matching: $package"
        /usr/sbin/pkgutil --pkgs | /usr/bin/grep -i "$package" | while read -r pkg; do
            echo "  Forgetting: $pkg"
            /usr/sbin/pkgutil --forget "$pkg"
        done
    fi
done

exit 0
