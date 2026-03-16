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
    export CAT_CMD=$SCRIPT_DIR/mock_cmd.sh
    export MOCK_ARGUMENT_FILE=$(mktemp)
    export MOCK_TRACKING_FILE=$(mktemp)
    unset JIRA_USERNAME
    unset JIRA_API_TOKEN
    unset JIRA_DOMAIN
    unset JIRA_CONFIG
}

echo Scenario: Get Jira configuration from separate env values
beforeEach

# GIVEN
export JIRA_USERNAME="user"
export JIRA_API_TOKEN="token"
export JIRA_DOMAIN="company"
export MOCK_RESPONSES='[{}]'

# WHEN
ACTUAL_RESULT=$($CMD)

# THEN
assert_equals '{"auth": {"user":"user","token":"token"},"jira": {"domain": "company"}}' "$ACTUAL_RESULT"

echo Scenario: Get Jira configuration from config env value
beforeEach

# GIVEN
export JIRA_CONFIG="{}"
export MOCK_RESPONSES='[{}]'

# WHEN
ACTUAL_RESULT=$($CMD)

# THEN
assert_equals "{}" "$ACTUAL_RESULT"

echo Scenario: Get Jira configuration from config file
beforeEach

# GIVEN
export MOCK_RESPONSES='[
    {"stdout": "{\"auth\": {\"user\":\"user\",\"token\":\"token\"},\"jira\": {\"domain\": \"company\"}}"}
]'

# WHEN
ACTUAL_RESULT=$($CMD)

# THEN
assert_equals '{"auth": {"user":"user","token":"token"},"jira": {"domain": "company"}}' "$ACTUAL_RESULT"