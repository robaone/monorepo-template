#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
JIRA_CONFIG="$($SCRIPT_DIR/jira_get_config.sh)"

JIRA_API_TOKEN=$(echo $JIRA_CONFIG | jq -r .auth.token)
JIRA_USERNAME=$(echo $JIRA_CONFIG | jq -r .auth.user)
JIRA_DOMAIN=$(echo $JIRA_CONFIG | jq -r .jira.domain)

# Variables
JQL_QUERY="$2"
FIX_VERSION="$1"

if [ "$JIRA_DOMAIN" == "" ] || [ "$JIRA_DOMAIN" == "null" ]; then
  echo "Please set the jira domain in the config file"
  exit
fi

if [ "$FIX_VERSION" == "" ] || [ "$JQL_QUERY" == "" ]; then
  echo "Usage: [fix version] [jql query]"
  exit 1
fi

function urlEncode() {
  echo "$1" | jq -s -R -r @uri
}

JQL_QUERY=$(urlEncode "$JQL_QUERY")

# Get the list of issues matching the JQL query
response=$(curl -s -u $JIRA_USERNAME:$JIRA_API_TOKEN -X GET -H "Content-Type: application/json" "https://$JIRA_DOMAIN/rest/api/2/search?jql=$JQL_QUERY")

# Extract issue keys from the response
issue_keys=$(echo $response | jq -r '.issues[].key')

# Loop through each issue key and remove the fixVersion
for issue_key in $issue_keys; do
  echo "Removing fixVersion from issue: $issue_key"
  curl -s -u $JIRA_USERNAME:$JIRA_API_TOKEN -X PUT -H "Content-Type: application/json" \
    --data "{\"update\": {\"fixVersions\": [{\"remove\": {\"name\": \"$FIX_VERSION\"}}]}}" \
    "https://$JIRA_DOMAIN/rest/api/2/issue/$issue_key"
done

echo "FixVersion removal completed."
