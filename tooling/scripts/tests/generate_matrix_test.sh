#!/bin/bash

CMD=$1

SCRIPT_DIR=$(cd $(dirname $0); pwd)

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
    export FILE_EXISTS_CMD=$SCRIPT_DIR/mock_cmd.sh
    export CAT_CMD=$SCRIPT_DIR/mock_cmd.sh
}

echo Scenario: Generate a matrix object string where project.json does not exist
beforeEach

# GIVEN

export DEFAULT_OS="pop-os-20.04"
export PROJECTS="my-pop-project"
export MOCK_RESPONSES='[
  {"stdout":"0"}
]'


# WHEN

ACTUAL_RESULT=$(echo "$PROJECTS" | $CMD)

# THEN

assert_equals '{"include":[{"project":"."},{"project":"my-pop-project"}]}' "$ACTUAL_RESULT"
