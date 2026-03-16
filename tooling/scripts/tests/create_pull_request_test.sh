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

function beforeAll() {
  export PR_TYPE=1
  export PARTIAL_IMPLEMENTATION="n"
}

function beforeEach() {
    export SCRIPT_PATH=$SCRIPT_DIR/mock_cmd.sh
    export GIT_PATH=$SCRIPT_DIR/mock_cmd.sh
    export GIFS_FILE=$(mktemp)
    export MOCK_ARGUMENT_FILE=$(mktemp)
    export MOCK_TRACKING_FILE=$(mktemp)
}

beforeAll

echo Scenario: Create a new pull request
beforeEach

# GIVEN
export PR_TITLE="My pull request"
export GIF_URL="https://my.domain/image.gif"
echo '{"MY":"https://my.domain/image.gif"}' > $GIFS_FILE
export MOCK_RESPONSES='[
{"name": "Get git branch", "stdout": "feature/MY-123"},
{"stdout": "SUCCESS"}
]'

# WHEN
ACTUAL_RESULT=$($CMD "$PR_TITLE" "$GIF_URL")

# THEN
assert_equals "rev-parse --abbrev-ref HEAD
feat: $PR_TITLE $GIF_URL false" "$(cat $MOCK_ARGUMENT_FILE)"

echo Scenario: Create a new pull request with default gif
beforeEach

# GIVEN
export PR_TITLE="My pull request"
export GIF_URL="https://my.domain/default.gif"
echo '{"MY":"https://my.domain/image.gif", "default": "https://my.domain/default.gif"}' > $GIFS_FILE
export MOCK_RESPONSES='[
{"name": "Get git branch", "stdout": "feature/OTHER-123"},
{"stdout": "SUCCESS"}
]'

# WHEN
ACTUAL_RESULT=$($CMD "$PR_TITLE" "$GIF_URL")

# THEN
assert_equals "rev-parse --abbrev-ref HEAD
feat: $PR_TITLE $GIF_URL false" "$(cat $MOCK_ARGUMENT_FILE)"
