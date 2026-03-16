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
    export GIT_PATH=$SCRIPT_DIR/mock_cmd.sh
    export MOCK_ARGUMENT_FILE=$(mktemp)
    export MOCK_TRACKING_FILE=$(mktemp)
}

echo Scenario: Get the default develop branch
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"stdout":"/path/to/repo"}
]'

# WHEN
ACTUAL_RESULT=$($CMD develop)

# THEN
assert_equals "develop" "$ACTUAL_RESULT"

echo Scenario: Get the default main branch
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"stdout":"/path/to/repo"}
]'

# WHEN
ACTUAL_RESULT=$($CMD main)

# THEN
assert_equals "main" "$ACTUAL_RESULT"

echo Scenario: Get the custom develop branch
beforeEach

# GIVEN
echo "{\"git\":{\"develop\":\"develop-branch\"}}" > $SCRIPT_DIR/.git-flow.json
export MOCK_RESPONSES='[
{"stdout":"'$SCRIPT_DIR'"}
]'

# WHEN
ACTUAL_RESULT=$($CMD develop)
rm $SCRIPT_DIR/.git-flow.json

# THEN
assert_equals "develop-branch" "$ACTUAL_RESULT"

echo Scenario: Get the custom main branch
beforeEach

# GIVEN
echo "{\"git\":{\"main\":\"main-branch\"}}" > $SCRIPT_DIR/.git-flow.json
export MOCK_RESPONSES='[
{"stdout":"'$SCRIPT_DIR'"}
]'

# WHEN
ACTUAL_RESULT=$($CMD main)
rm $SCRIPT_DIR/.git-flow.json

# THEN
assert_equals "main-branch" "$ACTUAL_RESULT"
