#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CMD="$1"

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
    export GET_PAGE_CMD=$SCRIPT_DIR/mock_cmd.sh
    export CREATE_PAGE_CMD=$SCRIPT_DIR/mock_cmd.sh
    export JIRA_CONFIG='{"auth":{"user":"test","token":"test"},"jira":{"domain":"test"}}'
}

function beforeEach() {
  export YEAR="2024"
  export RELEASE_NAME="Test Release"
  export RELEASE_END_DATE="2024-01-31"
  export RELEASE_FOLDER_CONTENT="Release notes for 2024.  Custom content."
  export RELEASE_NOTES_FILE=$(mktemp)
  export MOCK_RESPONSES='[]'
  export MOCK_ARGUMENT_FILE=$(mktemp)
  export MOCK_TRACKING_FILE=$(mktemp)
}

beforeAll

echo Scenario: Return error if the YEAR is not provided
beforeEach

# GIVEN
YEAR=""

# WHEN
ACTUAL_RESULT="$($CMD "$YEAR" "$RELEASE_NAME" "$RELEASE_END_DATE" $RELEASE_NOTES_FILE)"

# THEN
assert_equals "1" "$?"
assert_equals "Usage: [year] [release_name] [release_end_date] [release_notes_file]" "$ACTUAL_RESULT"

echo Scenario: Return error if the RELEASE_NAME is not provided
beforeEach

# GIVEN
RELEASE_NAME=""

# WHEN
ACTUAL_RESULT="$($CMD "$YEAR" "$RELEASE_NAME" "$RELEASE_END_DATE" $RELEASE_NOTES_FILE)"

# THEN
assert_equals "1" "$?"
assert_equals "Usage: [year] [release_name] [release_end_date] [release_notes_file]" "$ACTUAL_RESULT"

echo Scenario: Return error if the RELEASE_END_DATE is not provided
beforeEach

# GIVEN
RELEASE_END_DATE=""

# WHEN
ACTUAL_RESULT="$($CMD "$YEAR" "$RELEASE_NAME" "$RELEASE_END_DATE" $RELEASE_NOTES_FILE)"

# THEN
assert_equals "1" "$?"
assert_equals "Usage: [year] [release_name] [release_end_date] [release_notes_file]" "$ACTUAL_RESULT"

echo Scenario: Return error if the RELEASE_NOTES_FILE is not provided
beforeEach

# GIVEN
RELEASE_NOTES_FILE=""

# WHEN
ACTUAL_RESULT="$($CMD "$YEAR" "$RELEASE_NAME" "$RELEASE_END_DATE" $RELEASE_NOTES_FILE)"

# THEN
assert_equals "1" "$?"
assert_equals "Usage: [year] [release_name] [release_end_date] [release_notes_file]" "$ACTUAL_RESULT"

echo Scenario: Create a new release page
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"name":"get parent page","stdout":"{\"id\":\"1234\",\"spaceId\": 555}"},
{"name":"create folder","stdout":"{\"id\": 5678}"},
{"name":"create release notes","stdout":"{\"id\": 6789}"}
]'
echo "These are the release notes" > $RELEASE_NOTES_FILE

# WHEN
ACTUAL_RESULT="$($CMD "$YEAR" "$RELEASE_NAME" "$RELEASE_END_DATE" "$RELEASE_NOTES_FILE")"

# THEN
assert_equals "-i 4489150471
4489150471 555 2024-01-31 Release Notes - Test Release These are the release notes" "$(cat $MOCK_ARGUMENT_FILE)"
assert_equals "{\"id\": 5678}" "$ACTUAL_RESULT"