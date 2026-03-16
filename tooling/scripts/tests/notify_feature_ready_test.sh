#!/bin/bash

CMD=$1

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function assert_equals {
  if [ "$1" != "$2" ]; then
    echo "Expected: $1"
    echo "Actual:   $2"
    exit 1
  else
    echo "OK"
  fi
}

function beforeEach {
    export MOCK_ARGUMENT_FILE=$(mktemp)
    export MOCK_TRACKING_FILE=$(mktemp)
    export CURL_CMD=$SCRIPT_DIR/mock_cmd.sh
    export JQ_CMD=$SCRIPT_DIR/mock_cmd.sh
    export GIT_CMD=$SCRIPT_DIR/mock_cmd.sh
    export JIRA_API_TOKEN="api-token"
    export PULL_REQUEST_URL="https://github.com/owner/repo/pulls/1"
    export JIRA_API_USERNAME="username@domain.com"
    export JIRA_DOMAIN="your-jira-domain.atlassian.net"
    export PULL_REQUEST_DESCRIPTION="description"
    export PULL_REQUEST_TITLE="title CORE-1234, CORE-4567"
    export MOCK_ARGUMENT_FILE=$(mktemp)
    export MOCK_TRACKING_FILE=$(mktemp)
    export MOCK_RESPONSES='[{"stdout":"Jira Comment Created"},{"stdout":"Jira Comment Created"}]'
}

echo Scenario: Missing jira api token
beforeEach

# GIVEN
export JIRA_API_TOKEN=""

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert_equals "1" "$?"
assert_equals "JIRA_API_TOKEN is required" "$ACTUAL_RESULT"

echo Scenario: Missing pull request url
beforeEach

# GIVEN
export PULL_REQUEST_URL=""

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert_equals "1" "$?"
assert_equals "PULL_REQUEST_URL is required" "$ACTUAL_RESULT"

echo Scenario: Missing jira api username
beforeEach

# GIVEN
export JIRA_API_USERNAME=""

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert_equals "1" "$?"
assert_equals "JIRA_API_USERNAME is required" "$ACTUAL_RESULT"

echo Scenario: Missing jira domain
beforeEach

# GIVEN

export JIRA_DOMAIN=""

# WHEN

ACTUAL_RESULT="$($CMD)"

# THEN

assert_equals "1" "$?"
assert_equals "JIRA_DOMAIN is required" "$ACTUAL_RESULT"

echo Scenario: Missing pull request description
beforeEach

# GIVEN

export PULL_REQUEST_DESCRIPTION=""

# WHEN

ACTUAL_RESULT="$($CMD)"

# THEN

assert_equals "1" "$?"
assert_equals "PULL_REQUEST_DESCRIPTION is required" "$ACTUAL_RESULT"

echo Scenario: Create Jira comment with pull request description and link
beforeEach

# GIVEN

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert_equals "0" "$?"
assert_equals "Jira Comment Created
Jira Comment Created" "$ACTUAL_RESULT"
assert_equals '-u username@domain.com:api-token -X POST -H Content-Type: application/json -d {
  "body": "h1. title ,\nhttps://github.com/owner/repo/pulls/1\ndescription"
} https://your-jira-domain.atlassian.net/rest/api/2/issue/CORE-1234/comment
-u username@domain.com:api-token -X POST -H Content-Type: application/json -d {
  "body": "h1. title ,\nhttps://github.com/owner/repo/pulls/1\ndescription"
} https://your-jira-domain.atlassian.net/rest/api/2/issue/CORE-4567/comment' "$(cat $MOCK_ARGUMENT_FILE)"
