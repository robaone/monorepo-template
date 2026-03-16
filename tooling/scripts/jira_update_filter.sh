#!/bin/bash

# Usage: ./update_jira_filter.sh <FILTER_ID> <JQL>

# Variables
FILTER_ID="$1"          # Filter ID to update
JQL="$2"                # New JQL statement

if [ "$JIRA_DOMAIN" == "" ] || [ "$JIRA_USERNAME" == "" ] || [ "$JIRA_API_TOKEN" == "" ]; then
  echo "Please set JIRA_DOMAIN, JIRA_USERNAME, and JIRA_API_TOKEN environment variables."
  exit 1
fi

# Check if all arguments are provided
if [ $# -lt 2 ]; then
  echo "Usage: [FILTER_ID] [JQL]"
  exit 1
fi

# API Endpoints
FILTER_URL="https://${JIRA_DOMAIN}/rest/api/3/filter/${FILTER_ID}"

# Fetch existing filter details
FILTER_DETAILS=$(curl -s \
  -X GET \
  -u "${JIRA_USERNAME}:${JIRA_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "${FILTER_URL}")

# Check if the filter retrieval was successful
if [ -z "$FILTER_DETAILS" ] || echo "$FILTER_DETAILS" | grep -q "errorMessages"; then
  echo "Failed to fetch filter details. Response:"
  echo "$FILTER_DETAILS"
  exit 1
fi

# Extract current name and description
CURRENT_NAME=$(echo "$FILTER_DETAILS" | jq -r '.name')
CURRENT_DESCRIPTION=$(echo "$FILTER_DETAILS" | jq -r '.description')

# JSON Payload for updating the filter
PAYLOAD=$(cat <<EOF
{
  "name": "${CURRENT_NAME}",
  "jql": "${JQL}",
  "description": "${CURRENT_DESCRIPTION}"
}
EOF
)

# Update filter via API
RESPONSE=$(curl -s -o response.json -w "%{http_code}" \
  -X PUT \
  -u "${JIRA_USERNAME}:${JIRA_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "${PAYLOAD}" \
  "${FILTER_URL}")

# Check HTTP response code
if [ "$RESPONSE" -eq 200 ]; then
  echo "Filter updated successfully!"
  cat response.json | jq
else
  echo "Failed to update filter. HTTP Response: $RESPONSE"
  cat response.json
fi

# Clean up
rm -f response.json
