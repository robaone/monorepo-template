#!/bin/bash

# Send domain deployment status

domain=$1
status=$2

if [ -z "$domain" ] || [ -z "$status" ]; then
  echo "Usage: $0 <domain> <status>"
  exit 1
fi

# Construct JSON payload properly
json_payload=$(cat <<EOF
{"domain": "$domain", "status": "$status"}
EOF
)

response="$(curl -X POST "https://script.google.com/macros/s/AKfycbzTnFBzPHL2eGVOE7wZm9b0PV1-tE2itBs9A3AyGEh3-KmdgzCbeB0d22DokVdnACI8/exec" \
  -H "Content-Type: application/json" \
  -d "$json_payload" 2> /dev/null)"

echo "Done"
exit $?