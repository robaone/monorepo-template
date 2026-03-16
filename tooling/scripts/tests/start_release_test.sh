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
  export PULL_REQUEST_BODY_PATH="$SCRIPT_DIR/mock_cmd.sh"
  export GIT_PATH="$SCRIPT_DIR/mock_cmd.sh"
  export GH_PATH=$SCRIPT_DIR/mock_cmd.sh
  export GIT_FLOW_BRANCH_CMD=$SCRIPT_DIR/mock_cmd.sh
}

function beforeEach {
  export PACKAGE_JSON_PATH=$(mktemp)
  export MOCK_ARGUMENT_FILE=$(mktemp)
  export MOCK_TRACKING_FILE=$(mktemp)
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
beforeAll

echo Scenario: Start a release by creating the release branch and the pull requests
beforeEach

# GIVEN

export PACKAGE_JSON_CONTENT='{"version":"1.0.0"}'
echo $PACKAGE_JSON_CONTENT > $PACKAGE_JSON_PATH
export PREDICTED_VERSION=1.0.0
export MOCK_RESPONSES='[
{"name":"Gitflow branch","stdout":"develop"},
{"name":"Gitflow branch","stdout":"main"},
{"name":"checkout main"},
{"name":"pull main"},
{"name":"fetch --all"},
{"name":"Checkout develop branch"},
{"name":"Pull"},
{"name":"Checkout existing release branch","exit":1},
{"name":"Create release branch"},
{"name":"Push branch"},
{"name":"List pull requests for this branch to main"},
{"name":"Create pr body","stdout":"Release v1.0.0"},
{"name":"Create pull request to main","stdout":"CREATED"}
]'

# WHEN

ACTUAL_RESULT=$($CMD)
# THEN

assert_equals "develop
main
checkout
pull
fetch --all
checkout develop
pull
checkout release/v1.0.0
checkout -b release/v1.0.0
push -u origin release/v1.0.0
pr list --base main --head release/v1.0.0 --json number --jq .[0].number

pr create --base main --head release/v1.0.0 --title release v1.0.0 to main --body Release v1.0.0" "$(cat $MOCK_ARGUMENT_FILE)"

echo Scenario: Start a release by creating the release branch and the pull requests where the release branch already exists
beforeEach

# GIVEN

export PACKAGE_JSON_CONTENT='{"version":"1.0.0"}'
echo $PACKAGE_JSON_CONTENT > $PACKAGE_JSON_PATH
export PREDICTED_VERSION=1.0.0
export MOCK_RESPONSES='[
{"stdout":"develop"},
{"stdout":"main"},
{"name":"checkout main"},
{"name":"pull main"},
{"name":"fetch --all"},
{"name":"Checkout develop branch"},
{"name":"Pull"},
{"exit":0},
{"name":"push -u origin release/v1.0.0"},
{"name":"pr list --base main"},
{"name":"Create pr body","stdout":"Release v1.0.0"},
{"stdout":"CREATED"}
]'

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "develop
main
checkout
pull
fetch --all
checkout develop
pull
checkout release/v1.0.0
push -u origin release/v1.0.0
pr list --base main --head release/v1.0.0 --json number --jq .[0].number

pr create --base main --head release/v1.0.0 --title release v1.0.0 to main --body Release v1.0.0" "$(cat $MOCK_ARGUMENT_FILE)"

echo Scenario: Start a release by creating the release branch and the pull requests where the release branch already exists and the pull request to main already exists
beforeEach

# GIVEN

export PACKAGE_JSON_CONTENT='{"version":"1.0.0"}'
echo $PACKAGE_JSON_CONTENT > $PACKAGE_JSON_PATH
export PREDICTED_VERSION=1.0.0
export MOCK_RESPONSES='[
{"name":"gitflow branch","stdout":"develop"},
{"name":"gitflow branch","stdout":"main"},
{"name":"checkout main"},
{"name":"pull main"},
{"name":"fetch --all"},
{"name":"Checkout develop branch"},
{"name":"Pull"},
{"name":"Checkout existing release branch","exit":0},
{"name":"Push branch"},
{"name":"pr list --base main","stdout":"47"}
]'

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "develop
main
checkout
pull
fetch --all
checkout develop
pull
checkout release/v1.0.0
push -u origin release/v1.0.0
pr list --base main --head release/v1.0.0 --json number --jq .[0].number" "$(cat $MOCK_ARGUMENT_FILE)"


echo Scenario: Start a release by creating the release branch and the pull requests where the release branch already exists and the pull requests already exist
beforeEach

# GIVEN

export PACKAGE_JSON_CONTENT='{"version":"1.0.0"}'
echo $PACKAGE_JSON_CONTENT > $PACKAGE_JSON_PATH
export PREDICTED_VERSION=1.0.0
export MOCK_RESPONSES='[
{"stdout":"develop"},
{"stdout":"main"},
{"name":"checkout main"},
{"name":"pull main"},
{"name":"fetch --all"},
{"name":"Checkout develop branch"},
{"name":"Pull"},
{"exit":0},
{},
{"stdout":"47"}
]'

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "develop
main
checkout
pull
fetch --all
checkout develop
pull
checkout release/v1.0.0
push -u origin release/v1.0.0
pr list --base main --head release/v1.0.0 --json number --jq .[0].number" "$(cat $MOCK_ARGUMENT_FILE)"

echo Scenario: Start a release by updating the package version, creating the release branch and the pull requests
beforeEach

# GIVEN

export PACKAGE_JSON_CONTENT='{"version":"1.0.0"}'
echo $PACKAGE_JSON_CONTENT > $PACKAGE_JSON_PATH
export PREDICTED_VERSION=1.1.0
export MOCK_RESPONSES='[
{"stdout":"develop"},
{"stdout":"main"},
{"name":"checkout main"},
{"name":"pull main"},
{"name":"fetch --all"},
{"name":"Checkout develop branch"},
{"name":"Pull"},
{"exit":1},
{"name":"Checkout new release branch"},
{"name":"Git add"},
{"name":"Git commit"},
{"name":"Git push"},
{"name":"GH pr list"},
{"name":"Create pr body","stdout":"Release v1.1.0"},
{"stdout":"CREATED"}
]'

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "develop
main
checkout
pull
fetch --all
checkout develop
pull
checkout release/v1.1.0
checkout -b release/v1.1.0
add $PACKAGE_JSON_PATH
commit -m chore: update package version to v1.1.0
push -u origin release/v1.1.0
pr list --base main --head release/v1.1.0 --json number --jq .[0].number

pr create --base main --head release/v1.1.0 --title release v1.1.0 to main --body Release v1.1.0" "$(cat $MOCK_ARGUMENT_FILE)"

echo Scenario: Start a release by creating the release branch and the pull request to main where there are no differences between the release branch and the develop branch
beforeEach

# GIVEN

export PACKAGE_JSON_CONTENT='{"version":"1.0.0"}'
echo $PACKAGE_JSON_CONTENT > $PACKAGE_JSON_PATH
export PREDICTED_VERSION=1.0.0
export MOCK_RESPONSES='[
{"stdout":"develop"},
{"stdout":"main"},
{"name":"checkout main"},
{"name":"pull main"},
{"name":"fetch --all"},
{"name":"Checkout develop branch"},
{"name":"Pull"},
{"exit":1},
{"name":"Checkout new release branch"},
{"name":"Git add"},
{"name":"Git commit"},
{"name":"Git push"},
{"name":"GH pr list"},
{"name":"Create pr body","stdout":"Release v1.0.0"},
{"stderr":"NOT CREATED","exit":1},
{},
{"name":"Create pr body","stdout":"Release v1.1.0"},
{"stdout":"CREATED"}
]'

# WHEN

ACTUAL_RESULT=$($CMD)

# THEN

assert_equals "$?" "0"
