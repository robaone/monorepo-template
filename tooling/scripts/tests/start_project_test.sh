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

parent_folder=$(dirname $SCRIPT_DIR)

export TEST=true

function beforeEach() {
    export MKDIR_CMD=$SCRIPT_DIR/mock_cmd.sh
    export CP_CMD=$SCRIPT_DIR/mock_cmd.sh
    export SED_CMD=$SCRIPT_DIR/mock_cmd.sh
    export MOCK_ARGUMENT_FILE=$(mktemp)
    export MOCK_TRACKING_FILE=$(mktemp)
}

echo Scenario: Create a new project
beforeEach

# GIVEN
export PROJECT_NAME="my-project"
export MOCK_RESPONSES='[{},{},{}]'

# WHEN
ACTUAL_RESULT=$($CMD $PROJECT_NAME)

# THEN
assert_equals "$parent_folder/../../domains/my-project
$parent_folder/../templates/package.json $parent_folder/../../domains/my-project/package.json" "$(cat $MOCK_ARGUMENT_FILE)"