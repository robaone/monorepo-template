#!/bin/bash

# Send domain deployment status

domain=$1
status=$2

if [ -z "$domain" ] || [ -z "$status" ]; then
  echo "Usage: $0 <domain> <status>"
  exit 1
fi

if [ -z "$DOMAIN_HEALTH_WEBHOOK_URL" ]; then
  echo "DOMAIN_HEALTH_WEBHOOK_URL is required"
  exit 1
fi

# Construct JSON payload properly
json_payload=$(cat <<EOF
{"domain": "$domain", "status": "$status"}
EOF
)

response="$(curl -X POST "$DOMAIN_HEALTH_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$json_payload" 2> /dev/null)"

echo "Done"
exit $?