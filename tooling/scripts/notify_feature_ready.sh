#!/bin/bash

set -e

function setup_environment_variables() {
  if [ "$CURL_CMD" == "" ]; then
    CURL_CMD="curl"
  fi
  if [ "$JQ_CMD" == "" ]; then
    JQ_CMD="jq"
  fi
  if [ "$GIT_CMD" == "" ]; then
    GIT_CMD="git"
  fi
}

function validate_env_vars() {
  if [ "$PULL_REQUEST_URL" == "" ]; then
    echo "PULL_REQUEST_URL is required"
    exit 1
  fi
  if [ "$JIRA_API_TOKEN" == "" ]; then
    echo "JIRA_API_TOKEN is required"
    exit 1
  fi
  if [ "$JIRA_API_USERNAME" == "" ]; then
    echo "JIRA_API_USERNAME is required"
    exit 1
  fi
  if [ "$JIRA_DOMAIN" == "" ]; then
    echo "JIRA_DOMAIN is required"
    exit 1
  fi
  if [ "$PULL_REQUEST_DESCRIPTION" == "" ]; then
    echo "PULL_REQUEST_DESCRIPTION is required"
    exit 1
  fi
  if [ "$TARGET_BRANCH" == "" ]; then
    TARGET_BRANCH="origin/develop"
  fi
}

function get_ticket_ids() {
  local pr_title="$1"
  local ticket_ids=$(echo $pr_title | grep -o -E "[A-Z]+-[0-9]+" | sort | uniq)
  echo "$ticket_ids"
}

function pull_request_comment() {
  local pr_title="$(echo "$1" | sed -E 's/[A-Z]+-[0-9]+//g' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
  local pull_request_url="$2"
  local description="$3"

  # Convert headers
  description=$(echo "$description" | sed -E 's/^### (.+)/h3. \1/g') # Convert ### to h3
  description=$(echo "$description" | sed -E 's/^## (.+)/h2. \1/g') # Convert ## to h2
  description=$(echo "$description" | sed -E 's/^# (.+)/h1. \1/g')  # Convert # to h1

  # Convert bold and italics
  description=$(echo "$description" | sed -E 's/\*\*([^*]+)\*\*/\*\1\*/g') # Convert **bold** to *bold*
  description=$(echo "$description" | sed -E 's/_([^_]+)_/_\1_/g')         # Convert _italics_ to _italics_

  # Convert unordered lists
  description=$(echo "$description" | sed -E 's/^-\s+/• /g')               # Convert - to bullet points

  # Convert code blocks
  description=$(echo "$description" | sed -E 's/^```/{{code}}/g')          # Replace ``` with {code}

  # Convert inline code
  description=$(echo "$description" | sed -E 's/`([^`]+)`/{{\1}}/g')       # Replace `inline code` with {{inline code}}

  # Convert HTML image tags to Confluence format
  description=$(echo "$description" | sed -E 's/<img src="([^"]+)"[^>]*>/!\1!/g') # Convert <img> to !image_url!

  local message="h1. ${pr_title}
${pull_request_url}
$description"
  echo "$message"
}

function create_jira_comment() {
  local ticket_ids="$1"
  local message="$2"
  local jira_domain="$3"
  local jira_api_username="$4"
  local jira_api_token="$5"
  for ticket_id in $ticket_ids; do
    # Skip ticket IDs matching ignored project key prefixes (comma-separated, e.g. "PAR,VIBES,LE")
    if [ -n "$JIRA_IGNORED_PROJECT_KEYS" ]; then
      skip=false
      IFS=',' read -ra ignored_keys <<< "$JIRA_IGNORED_PROJECT_KEYS"
      for key in "${ignored_keys[@]}"; do
        key=$(echo "$key" | tr -d '[:space:]')
        if [[ "$ticket_id" =~ ^${key}- ]]; then
          skip=true
          break
        fi
      done
      if [ "$skip" = true ]; then
        continue
      fi
    fi
    local comment_url="https://${jira_domain}/rest/api/2/issue/${ticket_id}/comment"
    local comment_data=$(jq -n --arg body "$message" '{body: $body}')
    $CURL_CMD -u "${jira_api_username}:${jira_api_token}" -X POST -H "Content-Type: application/json" -d "${comment_data}" "${comment_url}"
  done
}


function main() {
  validate_env_vars
  setup_environment_variables
  local pull_request_url="$PULL_REQUEST_URL"
  local description="$PULL_REQUEST_DESCRIPTION"
  local target_branch="$TARGET_BRANCH"
  local pr_title="$PULL_REQUEST_TITLE"
  local ticket_ids="$(get_ticket_ids "$pr_title")"
  local message=$(pull_request_comment "$pr_title" "$pull_request_url" "$description")
  create_jira_comment "$ticket_ids" "$message" "$JIRA_DOMAIN" "$JIRA_API_USERNAME" "$JIRA_API_TOKEN"
}

echo "=== converting the following description ===" >&2
echo "$PULL_REQUEST_DESCRIPTION" >&2
main
