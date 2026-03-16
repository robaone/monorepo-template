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
    export GIT_FLOW_BRANCH_CMD=$SCRIPT_DIR/mock_cmd.sh
    export GH_CMD=$SCRIPT_DIR/mock_cmd.sh
    export GIT_CMD=$SCRIPT_DIR/mock_cmd.sh
    export TEMP_FILE=$(mktemp)
    export TOOLING_CONFIG_FILE=$(mktemp)
    export MOCK_ARGUMENT_FILE=$(mktemp)
    export MOCK_TRACKING_FILE=$(mktemp)
}

echo Scenario: Create a pull request with a branch containing a Jira ticket ID
beforeEach

# GIVEN
echo "{ \"jira\": { \"domain\": \"company\" }, \"workflow\": { \"skippable\" : { \"cd\": false, \"e2e\": false }} }" > $TOOLING_CONFIG_FILE
export DESCRIPTION="My description"
export MOCK_RESPONSES='[
{"name": "Get current branch", "stdout": "* feature/COMPANY-1234-my-feature-branch"},
{"name": "Get target branch", "stdout": "develop"},
{"name": "Get label list", "stdout": ""},
{"name": "Create label"},
{"name": "Create pull request"}
]'

# WHEN
ACTUAL_RESULT=$($CMD "Title" "https://gif.url" false)

# THEN
assert_equals "<img width=\"250\" src=\"https://gif.url\" />

### Description:

My description

### Ticket:

https://company.atlassian.net/browse/COMPANY-1234


### Changes: (complexity: ?)

- [ ] Change 1

### Validation:

- [ ] Validation 1" "$(cat $TEMP_FILE)"

echo Scenario: Create a pull request with a branch containing a Jira ticket ID with skip e2e support
beforeEach

# GIVEN
echo "{ \"jira\": { \"domain\": \"company\" }, \"workflow\": { \"skippable\" : { \"cd\": false, \"e2e\": true }} }" > $TOOLING_CONFIG_FILE
export DESCRIPTION="My description"
export MOCK_RESPONSES='[
{"name": "Get current branch", "stdout": "* feature/COMPANY-1234-my-feature-branch"},
{"name": "Get target branch", "stdout": "develop"},
{"name": "Get label list", "stdout": ""},
{"name": "Create label"}
]'

# WHEN
ACTUAL_RESULT=$($CMD "Title" "https://gif.url" false)

# THEN
assert_equals "<img width=\"250\" src=\"https://gif.url\" />

### Description:

My description

### Ticket:

https://company.atlassian.net/browse/COMPANY-1234

- [x] Skip e2e

### Changes: (complexity: ?)

- [ ] Change 1

### Validation:

- [ ] Validation 1" "$(cat $TEMP_FILE)"

echo Scenario: Create a pull request with a branch containing a Jira ticket ID and is a partial implementation
beforeEach

# GIVEN
echo "{ \"jira\": { \"domain\": \"company\" }, \"workflow\": { \"skippable\" : { \"cd\": false, \"e2e\": false }} }" > $TOOLING_CONFIG_FILE
export DESCRIPTION="My description"
export MOCK_RESPONSES='[
{"name": "Get current branch", "stdout": "* feature/COMPANY-1234-my-feature-branch"},
{"name": "Get target branch", "stdout": "develop"},
{"name": "Get label list", "stdout": ""},
{"name": "Create label"},
{"name": "Create pull request"}
]'

# WHEN
ACTUAL_RESULT=$($CMD "Title" "https://gif.url" true)

# THEN
assert_equals "<img width=\"250\" src=\"https://gif.url\" />

### Description:

My description

### Ticket:

https://company.atlassian.net/browse/COMPANY-1234

- [x] Partial Implementation

### Changes: (complexity: ?)

- [ ] Change 1

### Validation:

- [ ] Validation 1" "$(cat $TEMP_FILE)"