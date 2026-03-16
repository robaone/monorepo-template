#!/bin/bash

CMD=$1
SCRIPT_DIR=$(cd $(dirname $0); pwd)

# Check that the first argument is set.
if [ -z "$CMD" ]; then
  echo "Usage: $0 [command]"
  exit 1
fi

function assert_equals() {
  if [ "$1" != "$2" ]; then
    echo "Expected: $1"
    echo "Actual:   $2"
    exit 1
  else
    echo "OK"
  fi
}

function beforeEach() {
  unset JIRA_API_TOKEN
  unset JIRA_USERNAME
  unset JIRA_DOMAIN
  export JIRA_CONFIG='{"auth": {"user":"user","token":"token"},"jira": {"domain": "company"}}'
  export CURL_CMD=$SCRIPT_DIR/mock_cmd.sh
  export GIT_CMD=$SCRIPT_DIR/mock_cmd.sh
  export MOCK_ARGUMENT_FILE=$(mktemp)
  export MOCK_TRACKING_FILE=$(mktemp)
}

echo Scenario: Get status of tickets not yet in main
beforeEach

# GIVEN
export MOCK_RESPONSES='[
  {"stdout": "00000000000000000001"},
  {"stdout": "Comment for TICKET-123"},
  {"stdout": "{\"id\":1234, \"fields\": {\"status\": {\"name\": \"In Progress\"}}}"}
]'

# WHEN
ACTUAL_RESULT=$($CMD . origin/main)

# THEN
assert_equals '{"hash":"00000000000000000001","url":"https://company.atlassian.net/browse/TICKET-123","status":"In Progress"}' "$ACTUAL_RESULT"