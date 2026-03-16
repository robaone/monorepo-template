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
    export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/1234567890/1234567890/1234567890"
    export PULL_REQUEST_URL="https://github.com/owner/repo/pulls/1"
    export GITHUB_WORKFLOW_RUN_URL="https://github.com/owner/repo/actions/runs/1"
    export MOCK_ARGUMENT_FILE=$(mktemp)
    export MOCK_TRACKING_FILE=$(mktemp)
    export MOCK_RESPONSES='[{"stdout":"my-repo"},{"stdout":"1.0.0"},{"stdout":"Notification Sent"}]'
}

echo Scenario: Missing slack webhook url
beforeEach

# GIVEN
export SLACK_WEBHOOK_URL=""

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert_equals "1" "$?"
assert_equals "SLACK_WEBHOOK_URL is required" "$ACTUAL_RESULT"

echo Scenario: Missing pull request url
beforeEach

# GIVEN
export PULL_REQUEST_URL=""

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert_equals "1" "$?"
assert_equals "PULL_REQUEST_URL is required" "$ACTUAL_RESULT"

echo Scenario: Missing github workflow run url
beforeEach

# GIVEN
export GITHUB_WORKFLOW_RUN_URL=""

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert_equals "1" "$?"
assert_equals "GITHUB_WORKFLOW_RUN_URL is required" "$ACTUAL_RESULT"

echo Scenario: Notify slack deployment message
beforeEach

# GIVEN

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert_equals "0" "$?"
assert_equals "Notification Sent" "$ACTUAL_RESULT"
assert_equals "rev-parse --show-toplevel
-r .version package.json
-X POST -H Content-type: application/json --data {\"text\":\"⚙️ *Deploying my-repo-v1.0.0 to staging*\n• pr: https://github.com/owner/repo/pulls/1\n• workflow: https://github.com/owner/repo/actions/runs/1\"} https://hooks.slack.com/services/1234567890/1234567890/1234567890" "$(cat $MOCK_ARGUMENT_FILE)"
