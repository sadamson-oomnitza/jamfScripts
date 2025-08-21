#!/bin/bash

# Get boot time of the device (kernel)
bootTime=$(sysctl kern.boottime | awk '{print $5}' | tr -d ,)

# Convert boot time to a human-readable date and time format (ISO 8601: YYYY-MM-DDTHH:MM:SS)
prettyDate=$(date -jf %s "$bootTime" +%Y-%m-%dT%H:%M:%S)

# Output the result in the desired format
echo "<result>$prettyDate</result>"