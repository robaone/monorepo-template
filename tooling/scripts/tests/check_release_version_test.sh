#!/bin/bash

CMD=$1

function assert_equals {
  if [ "$1" != "$2" ]; then
    echo "Expected: $1"
    echo "Actual:   $2"
    exit 1
  else
    echo "OK"
  fi
}

function beforeEach() {
  export MOCK_ARGUMENT_FILE=$(mktemp)
  export MOCK_TRACKING_FILE=$(mktemp)
  export GIT_PATH="$SCRIPT_DIR/mock_cmd.sh"
  export JQ_PATH="$SCRIPT_DIR/mock_cmd.sh"
  export FIGLET_PATH="$SCRIPT_DIR/mock_cmd.sh"
}

SCRIPT_DIR=$(cd $(dirname $0); pwd)

echo Scenario: Check the release version
beforeEach
# GIVEN

export MOCK_RESPONSES='[{"stdout":"release/v1.0.0"},{"stdout":"1.0.0"},{"stdout":"1.0.0"}]'
export EVENT="pull_request"
export TARGET_BRANCH="main"
export NEXT_PREDICTED_RELEASE="1.0.0"

# WHEN

ACTUAL_RESULT="$($CMD)"

# THEN

assert_equals "Everything is good.  Ready to release
1.0.0" "$ACTUAL_RESULT"
assert_equals "rev-parse --abbrev-ref HEAD
-r .version ./package.json
version 1.0.0" "$(cat $MOCK_ARGUMENT_FILE)"

echo Scenario: A Hotfix has a major release
beforeEach
# GIVEN

export MOCK_RESPONSES='[
  {"name":"Current Branch","stdout":"hotfix/v1.1.0"},
  {"name":"Package Version","stdout":"1.1.0"},
  {"name":"Next Predicted Version","stdout":"1.1.0"}
]'
export EVENT="pull_request"
export TARGET_BRANCH="main"
export NEXT_PREDICTED_RELEASE="1.1.0"

# WHEN

ACTUAL_RESULT="$($CMD)"

# THEN

assert_equals "1" "$?"
assert_equals "Error: The hotfix branch indicates a minor release, but a patch release is expected.
Action: Ensure the branch name follows the patch release convention (e.g., hotfix/v1.0.x)." "$ACTUAL_RESULT"

echo Scenario: A Hotfix has a minor release
beforeEach

# GIVEN

export MOCK_RESPONSES='[
  {"name":"Current Branch","stdout":"hotfix/v1.0.1"},
  {"name":"Package Version","stdout":"1.0.1"},
  {"name":"Next Predicted Version","stdout":"1.0.1"}
]'
export EVENT="pull_request"
export TARGET_BRANCH="main"
export NEXT_PREDICTED_RELEASE="1.0.1"

# WHEN

ACTUAL_RESULT="$($CMD)"

# THEN

assert_equals "0" "$?"
assert_equals "Everything is good.  Ready to release
1.0.1" "$ACTUAL_RESULT"