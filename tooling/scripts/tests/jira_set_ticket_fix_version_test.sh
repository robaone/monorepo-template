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

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo Scenario: Ticket is not tagged

# GIVEN

export MOCK_ARGUMENT_FILE=$(mktemp)
export MOCK_RESPONSES='[{"stdout":"{\"fields\":{\"fixVersions\":[]}}"},{"stdout":"Updated"}]'
export MOCK_TRACKING_FILE=$(mktemp)
export JIRA_GET_TICKET_PATH="$SCRIPT_DIR/mock_cmd.sh"
export CURL_PATH="$SCRIPT_DIR/mock_cmd.sh"

# WHEN

ACTUAL_RESULT=$($CMD CC-1234 repo-v1.1.0)

# THEN

assert_equals "Updated" "$ACTUAL_RESULT"

echo Scenario: Ticket is already tagged

# GIVEN

export MOCK_ARGUMENT_FILE=$(mktemp)
export MOCK_RESPONSES='[{"stdout":"{\"fields\":{\"fixVersions\":[{\"name\":\"repo-v1.1.0\"}]}}"},{"stdout":"Updated"}]'
export MOCK_TRACKING_FILE=$(mktemp)
export JIRA_GET_TICKET_PATH="$SCRIPT_DIR/mock_cmd.sh"
export CURL_PATH="$SCRIPT_DIR/mock_cmd.sh"

# WHEN

ACTUAL_RESULT=$($CMD CC-1234 repo-v1.1.0)

# THEN

assert_equals "Ticket CC-1234 already has version repo-v1.1.0" "$ACTUAL_RESULT"