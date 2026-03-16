#!/bin/bash

function assert_equals() {
  if [ "$1" != "$2" ]; then
    echo "Expected: $1"
    echo "Actual:   $2"
    exit 1
  else
    echo "OK"
  fi
}

echo Scenario: Generate release notes

# GIVEN
OUTPUT_FILE=$(mktemp)

# WHEN
RESULTS="$(node tooling/scripts/generate_release_notes.js tooling/scripts/tests/data/jira_ticket_data.json $OUTPUT_FILE)"

# THEN
assert_equals "Release notes written to $OUTPUT_FILE" "$RESULTS"
cat $OUTPUT_FILE

echo Scenario: Publish release notes

# GIVEN
# RELEASE_DATE=$(date +"%Y-%m-%d")
RELEASE_DATE="2024-11-20"
export RELEASE_FOLDER_CONTENT="<h1>Test Release Notes</h1><p>This is a test page for release notes created on $(date +"%Y-%m-%d") at $(date +"%I:%M %p")</p>"
export UPDATE_EXISTING="true"
export PARENT_PAGE_ID=4636672344

# WHEN
RESULTS="$(./tooling/scripts/confluence_create_release_page.sh 2024 "repository-v1.0.0" "$RELEASE_DATE" $OUTPUT_FILE)"

# THEN
assert_equals "0" "$?"
echo "$RESULTS" | jq -r '"\(.["_links"].base)\(.["_links"].webui)"'
