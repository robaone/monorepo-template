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
}

function beforeEach() {
  export TEMPLATE_FILE=$(mktemp)
  echo "template-data" > $TEMPLATE_FILE
  export OPENAI_API_KEY="open-ai-api-key"
  export MOCK_ARGUMENT_FILE=$(mktemp)
  export MOCK_TRACKING_FILE=$(mktemp)
}

beforeAll

echo Scenario: No arguments
beforeEach

# GIVEN

# WHEN
ACTUAL_RESULT=$($CMD)

# THEN
assert_equals "1" "$?"
assert_equals "Usage: [template-file.yml]" "$ACTUAL_RESULT"

echo Scenario: Missing Open AI API Key
beforeEach

# GIVEN

unset OPENAI_API_KEY

# WHEN

ACTUAL_RESULT=$($CMD "$TEMPLATE_FILE")

# THEN

assert_equals "1" "$?"
assert_equals "Please set the OPENAI_API_KEY environment variable" "$ACTUAL_RESULT"

echo Scenario: Template file not found
beforeEach

# GIVEN

export TEMPLATE_FILE="non-existent-file"

# WHEN

ACTUAL_RESULT=$($CMD "$TEMPLATE_FILE")

# THEN

assert_equals "1" "$?"
assert_equals "Error: File 'non-existent-file' not found" "$ACTUAL_RESULT"

echo Scenario: Open AI Model failure
beforeEach

# GIVEN

export MOCK_RESPONSES='[
  {"stdout": "Error: Model not found", "exit": 1}
]'

# WHEN

ACTUAL_RESULT=$($CMD "$TEMPLATE_FILE")

# THEN

assert_equals "1" "$?"
assert_equals "Error: Model not found" "$ACTUAL_RESULT"

echo Scenario: Create the mermaid diagram
beforeEach

# GIVEN

export MOCK_RESPONSES='[
  {"stdout": "mermaid-diagram", "exit": 0}
]'

# WHEN

ACTUAL_RESULT=$($CMD "$TEMPLATE_FILE")

# THEN

assert_equals "0" "$?"
assert_equals "mermaid-diagram" "$ACTUAL_RESULT"
