#!/bin/bash

CMD=$1

if [ "$CMD" == "" ]; then
  echo "usage: $0 [command]"
  exit 1
fi

function assert_equals {
  if [ "$1" != "$2" ]; then
    echo "Expected: $1"
    echo "Actual:   $2"
    exit 1
  else
    echo "OK"
  fi
}

function beforeAll {
  export LATEST_VERSION=1.0.0
  export GIT_PATH="$SCRIPT_DIR/mock_cmd.sh"
  export PULL_REQUEST_BODY="Hotfix v1.0.1"
  export PACKAGE_JSON_PATH=$(mktemp)
  echo '{"version": "1.0.0"}' > $PACKAGE_JSON_PATH
}

function beforeEach {
  export GH_PATH="$SCRIPT_DIR/mock_cmd.sh"
  export MOCK_ARGUMENT_FILE=$(mktemp)
  export MOCK_TRACKING_FILE=$(mktemp)
}

SCRIPT_DIR=$(cd $(dirname $0); pwd)

beforeAll

echo Scenario: gh cli is not installed
beforeEach

# GIVEN

export GH_PATH="invalid"

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "Error: GitHub CLI (gh) is not installed or not executable
To install GitHub CLI:
  - On macOS: brew install gh
For other platforms, visit: https://github.com/cli/cli#installation" "$ACTUAL_RESULT"

echo Scenario: Fail to checkout main branch first
beforeEach

# GIVEN

export MOCK_RESPONSES='[
{"name":"fetch --all"},
{"name":"checkout main","exit":1}
]'

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "fetch --all
checkout main" "$(cat $MOCK_ARGUMENT_FILE)"
assert_equals "Error: Could not checkout main branch" "$ACTUAL_RESULT"

echo Scenario: Start a hotfix by creating the hotfix branch and the pull requests
beforeEach

# GIVEN

export MOCK_RESPONSES='[
{"name":"fetch --all"},
{"name":"checkout main"},
{"name":"pull"},
{"name":"checkout hotfix","exit":1},
{"name":"create hotfix branch"},
{"name":"git diff --name-only package.json","stdout":"package.json"},
{"name":"add package.json"},
{"name":"commit package.json"},
{"name":"push hotfix branch"},
{"name":"find pull request to main"},
{"name":"create pull request","stdout":"CREATED"}
]'

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "fetch --all
checkout main
pull
checkout hotfix/v1.0.1
checkout -b hotfix/v1.0.1
diff --name-only $PACKAGE_JSON_PATH
add $PACKAGE_JSON_PATH
commit -m chore: update package version to v1.0.1
push -u origin hotfix/v1.0.1
pr list --base main --head hotfix/v1.0.1 --json number --jq .[0].number
pr create --base main --head hotfix/v1.0.1 --title hotfix v1.0.1 to main --body Hotfix v1.0.1" "$(cat $MOCK_ARGUMENT_FILE)"

echo Scenario: Start a hotfix by creating the hotfix branch and the pull requests where the hotfix branch already exists
beforeEach

# GIVEN

export MOCK_RESPONSES='[
{"name":"fetch --all"},
{"name":"checkout main"},
{"name":"pull"},
{"name":"checkout hotfix","exit":0},
{"name":"git diff --name-only package.json","stdout":"package.json"},
{"name":"add package.json"},
{"name":"commit package.json"},
{"name":"push hotfix branch"},
{"name":"find pull request to main"},
{"name":"create pull request","stdout":"CREATED"}
]'

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "fetch --all
checkout main
pull
checkout hotfix/v1.0.1
diff --name-only $PACKAGE_JSON_PATH
add $PACKAGE_JSON_PATH
commit -m chore: update package version to v1.0.1
push -u origin hotfix/v1.0.1
pr list --base main --head hotfix/v1.0.1 --json number --jq .[0].number
pr create --base main --head hotfix/v1.0.1 --title hotfix v1.0.1 to main --body Hotfix v1.0.1" "$(cat $MOCK_ARGUMENT_FILE)"

echo Scenario: Start a hotfix by creating the hotfix branch and the pull requests where the hotfix branch already exists and the pull request to main already exists
beforeEach

# GIVEN

export MOCK_RESPONSES='[
{"name":"fetch --all"},
{"name":"checkout main"},
{"name":"pull"},
{"name":"checkout hotfix","exit":0},
{"name":"git diff --name-only package.json","stdout":"package.json"},
{"name":"add package.json"},
{"name":"commit package.json"},
{"name":"push hotfix branch"},
{"name":"pr list","stdout":"47"},
{}
]'

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "fetch --all
checkout main
pull
checkout hotfix/v1.0.1
diff --name-only $PACKAGE_JSON_PATH
add $PACKAGE_JSON_PATH
commit -m chore: update package version to v1.0.1
push -u origin hotfix/v1.0.1
pr list --base main --head hotfix/v1.0.1 --json number --jq .[0].number" "$(cat $MOCK_ARGUMENT_FILE)"


echo Scenario: Start a hotfix by creating the hotfix branch and the pull requests where the hotfix branch already exists and the pull requests already exist
beforeEach

# GIVEN

export MOCK_RESPONSES='[
{"name":"fetch --all"},
{"name":"checkout main"},
{"name":"pull"},
{"name":"checkout hotfix","exit":0},
{"name":"git diff --name-only package.json","stdout":"package.json"},
{"name":"add package.json"},
{"name":"commit package.json"},
{"name":"push hotfix branch"},
{"name":"find pull request to main","stdout":"47"}
]'

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "fetch --all
checkout main
pull
checkout hotfix/v1.0.1
diff --name-only $PACKAGE_JSON_PATH
add $PACKAGE_JSON_PATH
commit -m chore: update package version to v1.0.1
push -u origin hotfix/v1.0.1
pr list --base main --head hotfix/v1.0.1 --json number --jq .[0].number" "$(cat $MOCK_ARGUMENT_FILE)"
