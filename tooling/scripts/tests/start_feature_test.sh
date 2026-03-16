#!/bin/bash

CMD=$1

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

SCRIPT_DIR=$(cd $(dirname $0); pwd)
export GIT_CONFIG_PATH="$SCRIPT_DIR/mock_config.json"

echo Scenario: Start a feature by creating a new branch

# GIVEN
export FEATURE_NAME="My Feature"
export TICKET_ID="1"

# a temp file to store the argument file
export MOCK_ARGUMENT_FILE=$(mktemp)
export MOCK_TRACKING_FILE=$(mktemp)
export MOCK_RESPONSES='[{},{"stdout":"develop"}, {}, {}, {}]'
export GIT_PATH=$SCRIPT_DIR/mock_cmd.sh
export GIT_FLOW_BRANCH_CMD=$SCRIPT_DIR/mock_cmd.sh

# WHEN
ACTUAL_RESULT=$($CMD)

# THEN
assert_equals "branch -r
develop
checkout develop
pull
checkout -b feature/1-my-feature" "$(cat $MOCK_ARGUMENT_FILE)"

echo Scenario: Start a feature by creating a new branch when the branch already exists

# GIVEN
export FEATURE_NAME="My Feature"
export TICKET_ID="1"

# a temp file to store the argument file
export MOCK_ARGUMENT_FILE=$(mktemp)
export MOCK_TRACKING_FILE=$(mktemp)
export MOCK_RESPONSES='[{"stdout": "  origin/feature/1-my-feature"}]'
export GIT_PATH=$SCRIPT_DIR/mock_cmd.sh
export GIT_FLOW_BRANCH_CMD=$SCRIPT_DIR/mock_cmd.sh

# WHEN
ACTUAL_RESULT=$($CMD)

# THEN
assert_equals "1" "$?"
assert_equals "branch -r" "$(cat $MOCK_ARGUMENT_FILE)"