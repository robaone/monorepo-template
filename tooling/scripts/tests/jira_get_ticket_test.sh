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
    unset JIRA_API_TOKEN
    unset JIRA_USERNAME
    unset JIRA_DOMAIN
    export JIRA_CONFIG='{"auth": {"user":"user","token":"token"},"jira": {"domain": "company"}}'
    export CURL_CMD=$SCRIPT_DIR/mock_cmd.sh
    export MOCK_ARGUMENT_FILE=$(mktemp)
    export MOCK_TRACKING_FILE=$(mktemp)
}

echo Scenario: Get a Jira ticket with no options
beforeEach

# GIVEN
export TICKET_ID="COMPANY-1234"
export MOCK_RESPONSES='[{"stdout": "{\"id\":1234}"}]'

# WHEN
ACTUAL_RESULT=$($CMD $TICKET_ID)

# THEN
assert_equals '{
  "id": 1234
}' "$ACTUAL_RESULT"
assert_equals '-X GET --user user:token -H Content-Type: application/json https://company.atlassian.net/rest/api/2/issue/COMPANY-1234' "$(cat $MOCK_ARGUMENT_FILE)"

echo Scenario: Get a Jira ticket with history
beforeEach

# GIVEN
export TICKET_ID="COMPANY-1234"
export MOCK_RESPONSES='[{"stdout": "{\"id\":1234, \"changelog\": []}"}]'

# WHEN
ACTUAL_RESULT=$($CMD $TICKET_ID --history)

# THEN
assert_equals '{
  "id": 1234,
  "changelog": []
}' "$ACTUAL_RESULT"
assert_equals '-X GET --user user:token -H Content-Type: application/json https://company.atlassian.net/rest/api/2/issue/COMPANY-1234?expand=changelog' "$(cat $MOCK_ARGUMENT_FILE)"

echo Scenario: Get a Jira ticket with links
beforeEach

# GIVEN
export TICKET_ID="COMPANY-1234"
export MOCK_RESPONSES='[{"stdout": "{\"id\":1234, \"remotelink\": []}"}]'

# WHEN
ACTUAL_RESULT=$($CMD $TICKET_ID --links)

# THEN
assert_equals '{
  "id": 1234,
  "remotelink": []
}' "$ACTUAL_RESULT"
assert_equals '-X GET --user user:token -H Content-Type: application/json https://company.atlassian.net/rest/api/2/issue/COMPANY-1234/remotelink' "$(cat $MOCK_ARGUMENT_FILE)"