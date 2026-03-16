#!/bin/bash

# Check if file exists
if [ ! -f "$1" ]; then
    echo "Error: $1 not found"
    exit 1
fi

# Extract URL using grep and sed, and convert HTML entities
URL=$(grep -o 'HREF="[^"]*"' "$1" | sed 's/HREF="//;s/"//' | sed 's/&amp;/\&/g')

# Print the URL
echo "$URL" 