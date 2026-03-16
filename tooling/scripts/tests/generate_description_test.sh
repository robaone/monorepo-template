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
    export CURL_CMD=$SCRIPT_DIR/mock_cmd.sh
    export LLM_API_TOKEN=token
}

function beforeEach() {
    export MOCK_ARGUMENT_FILE=$(mktemp)
    export MOCK_TRACKING_FILE=$(mktemp)
}

beforeAll

echo Scenario: Generate a description
beforeEach

# GIVEN

export MOCK_RESPONSES='[{"stdout": "{\"candidates\": [{\"content\": {\"parts\":[{\"text\":\"This is a description\"}]}}]}"}]'

# WHEN

ACTUAL_RESULT=$($CMD "This is the input")

# THEN

assert_equals "This is a description" "$ACTUAL_RESULT"
assert_equals '-s -X POST https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-8b:generateContent?key=token -H Content-Type: application/json -d {
  "contents": [
    {
      "parts": [
        {
          "text": "Create a fun release description in 100 characters or less without identifiers:\nThis is the input"
        }
      ]
    }
  ]
}' "$(cat $MOCK_ARGUMENT_FILE)"