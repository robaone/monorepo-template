#!/bin/bash

CMD=$1

if [ "$CMD" == "" ]; then
  echo "usage: $0 [command]"
  exit 1
fi

function assert_equals {
  if [ "$1" != "$2" ]; then
    echo "Expected: $1"
    echo "Actual:   $2"
    exit 1
  else
    echo "OK"
  fi
}

function beforeAll {
  unset JIRA_API_TOKEN
  unset JIRA_USERNAME
  unset JIRA_DOMAIN
  export JIRA_CONFIG_FILE=$(mktemp)
  echo '{"jira": {"domain": "company"}}' > $JIRA_CONFIG_FILE
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

beforeAll

echo Scenario: Not on develop branch

# GIVEN

export MOCK_ARGUMENT_FILE=$(mktemp)
export MOCK_RESPONSES='[{"stdout":"master"},{"stdout":"1.0.0"},{},{}]'
export MOCK_TRACKING_FILE=$(mktemp)
export TICKET_STATUS_PATH="$SCRIPT_DIR/mock_cmd.sh" 
export GIT_CMD_PATH="$SCRIPT_DIR/mock_cmd.sh"

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "1" "$?"
assert_equals "rev-parse --abbrev-ref HEAD" "$(cat $MOCK_ARGUMENT_FILE)"
assert_equals "Must be on develop branch" "$ACTUAL_RESULT"

echo Scenario: No tickets

# GIVEN

export MOCK_ARGUMENT_FILE=$(mktemp)
export MOCK_RESPONSES='[{"stdout":"develop"},{"stdout":"1.0.0"},{},{}]'
export MOCK_TRACKING_FILE=$(mktemp)
export TICKET_STATUS_PATH="$SCRIPT_DIR/mock_cmd.sh"
export GIT_CMD_PATH="$SCRIPT_DIR/mock_cmd.sh"

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "rev-parse --abbrev-ref HEAD
branch -r
origin/develop origin/main" "$(cat $MOCK_ARGUMENT_FILE)"
assert_equals "No tickets found" "$ACTUAL_RESULT"

echo Scenario: One Ticket

# GIVEN

export MOCK_ARGUMENT_FILE=$(mktemp)
export MOCK_RESPONSES='[{"stdout":"develop"},{"stdout":"1.1.0"},{},{"stdout":"{\"url\":\"https://company.atlassian.net/browse/CC-1234\"}"},{"stdout":"Release created!"},{"stdout":"Updated"}]'
export MOCK_TRACKING_FILE=$(mktemp)
export TICKET_STATUS_PATH="$SCRIPT_DIR/mock_cmd.sh"
export GIT_PREDICT_NEXT_VERSION_PATH="$SCRIPT_DIR/mock_cmd.sh"
export CREATE_RELEASE_PATH="$SCRIPT_DIR/mock_cmd.sh"
export SET_TICKET_FIX_VERSION_PATH="$SCRIPT_DIR/mock_cmd.sh"
export GIT_CMD_PATH="$SCRIPT_DIR/mock_cmd.sh"

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "Tickets found: CC-1234
Release created!
Tag CC-1234 with practice-monorepo-v1.1.0
Updated" "$ACTUAL_RESULT"

echo Scenario: Two Tickets

# GIVEN

export MOCK_ARGUMENT_FILE=$(mktemp)
export MOCK_RESPONSES='[{"stdout":"develop"},{"stdout":"1.1.0"},{},{"stdout":"{\"url\":\"https://company.atlassian.net/browse/CC-1234\"}\n{\"url\":\"https://company.atlassian.net/browse/BB-9999\"}"},{"stdout":"Release created!"},{"stdout":"Updated"},{"stdout":"Release created!"},{"stdout":"Updated"}]'
export MOCK_TRACKING_FILE=$(mktemp)
export TICKET_STATUS_PATH="$SCRIPT_DIR/mock_cmd.sh"
export GIT_PREDICT_NEXT_VERSION_PATH="$SCRIPT_DIR/mock_cmd.sh"
export CREATE_RELEASE_PATH="$SCRIPT_DIR/mock_cmd.sh"
export SET_TICKET_FIX_VERSION_PATH="$SCRIPT_DIR/mock_cmd.sh"

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "Tickets found: BB-9999 CC-1234
Release created!
Tag BB-9999 with practice-monorepo-v1.1.0
Updated
Release created!
Tag CC-1234 with practice-monorepo-v1.1.0
Updated" "$ACTUAL_RESULT"

echo Scenario: Release already exists

# GIVEN

export MOCK_ARGUMENT_FILE=$(mktemp)
export MOCK_RESPONSES='[{"stdout":"develop"},{"stdout":"1.1.0"},{"stdout":"origin/release/v1.1.0"},{"stdout":"{\"url\":\"https://company.atlassian.net/browse/CC-1234\"}\n{\"url\":\"https://company.atlassian.net/browse/BB-9999\"}"},{"stdout":"Release created!"},{"stdout":"Updated"},{"stdout":"Release exists!"},{"stdout":"Updated"}]'
export MOCK_TRACKING_FILE=$(mktemp)
export TICKET_STATUS_PATH="$SCRIPT_DIR/mock_cmd.sh"
export GIT_PREDICT_NEXT_VERSION_PATH="$SCRIPT_DIR/mock_cmd.sh"
export CREATE_RELEASE_PATH="$SCRIPT_DIR/mock_cmd.sh"
export SET_TICKET_FIX_VERSION_PATH="$SCRIPT_DIR/mock_cmd.sh"

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "Tickets found: BB-9999 CC-1234
Release created!
Tag BB-9999 with practice-monorepo-v1.2.0
Updated
Release exists!
Tag CC-1234 with practice-monorepo-v1.2.0
Updated" "$ACTUAL_RESULT"

echo Scenario: One Ticket and Repository has upper case letters

# GIVEN

export REPOSITORY=MobileApp
export MOCK_ARGUMENT_FILE=$(mktemp)
export MOCK_RESPONSES='[{"stdout":"develop"},{"stdout":"1.1.0"},{},{"stdout":"{\"url\":\"https://company.atlassian.net/browse/CC-1234\"}"},{"stdout":"Release created!"},{"stdout":"Updated"}]'
export MOCK_TRACKING_FILE=$(mktemp)
export TICKET_STATUS_PATH="$SCRIPT_DIR/mock_cmd.sh"
export GIT_PREDICT_NEXT_VERSION_PATH="$SCRIPT_DIR/mock_cmd.sh"
export CREATE_RELEASE_PATH="$SCRIPT_DIR/mock_cmd.sh"
export SET_TICKET_FIX_VERSION_PATH="$SCRIPT_DIR/mock_cmd.sh"
export GIT_CMD_PATH="$SCRIPT_DIR/mock_cmd.sh"

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "Tickets found: CC-1234
Release created!
Tag CC-1234 with mobileapp-v1.1.0
Updated" "$ACTUAL_RESULT"

echo Scenario: Dry Run on One ticket

# GIVEN

export MOCK_ARGUMENT_FILE=$(mktemp)
export MOCK_RESPONSES='[{"stdout":"develop"},{"stdout":"1.1.0"},{},{"stdout":"{\"url\":\"https://company.atlassian.net/browse/CC-1234\"}"},{"stdout":"Release created!"},{"stdout":"Updated"}]'
export MOCK_TRACKING_FILE=$(mktemp)
export TICKET_STATUS_PATH="$SCRIPT_DIR/mock_cmd.sh"
export GIT_PREDICT_NEXT_VERSION_PATH="$SCRIPT_DIR/mock_cmd.sh"
export CREATE_RELEASE_PATH="$SCRIPT_DIR/mock_cmd.sh"
export SET_TICKET_FIX_VERSION_PATH="$SCRIPT_DIR/mock_cmd.sh"
export GIT_CMD_PATH="$SCRIPT_DIR/mock_cmd.sh"

# WHEN

ACTUAL_RESULT=$($CMD -dry-run)

# THEN

assert_equals "Tickets found: CC-1234
********************************
Next version: mobileapp-v1.1.0
********************************
mobileapp-v1.1.0 Next awesome release
Tag CC-1234 with mobileapp-v1.1.0
CC-1234 mobileapp-v1.1.0" "$ACTUAL_RESULT"

echo Scenario: Dry Run on One ticket skip assignment

# GIVEN

export MOCK_ARGUMENT_FILE=$(mktemp)
export MOCK_RESPONSES='[{"stdout":"develop"},{"stdout":"1.1.0"},{},{"stdout":"{\"url\":\"https://company.atlassian.net/browse/CC-1234\"}"},{"stdout":"Release created!"},{"stdout":"Updated"}]'
export MOCK_TRACKING_FILE=$(mktemp)
export TICKET_STATUS_PATH="$SCRIPT_DIR/mock_cmd.sh"
export GIT_PREDICT_NEXT_VERSION_PATH="$SCRIPT_DIR/mock_cmd.sh"
export CREATE_RELEASE_PATH="$SCRIPT_DIR/mock_cmd.sh"
export SET_TICKET_FIX_VERSION_PATH="$SCRIPT_DIR/mock_cmd.sh"
export GIT_CMD_PATH="$SCRIPT_DIR/mock_cmd.sh"
export SKIP_ASSIGN_TAG=true

# WHEN

ACTUAL_RESULT=$($CMD -dry-run)

# THEN

assert_equals "{\"next_version\": \"mobileapp-v1.1.0\"}" "$ACTUAL_RESULT"
