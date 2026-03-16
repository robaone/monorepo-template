#!/bin/bash

# This script to create a hotfix branch if it does not exist by using
# the next predicted version.
# It will push the branch to the remote repository and
# create a pull request that targets the main branch only.
# After successful production deployment, a workflow will automatically
# create a PR from main to develop and merge it if there are no conflicts.

SCRIPT_DIR="$(cd $(dirname $0); pwd)"

function incrementPatchVersion() {
  local latest_version=$1
  local patch_version=$(echo $latest_version | awk -F. '{print $3}')
  echo $(echo $latest_version | awk -F. '{print $1"."$2"."$3+1}')
}

function fetchAllRemoteBranches() {
  $GIT_PATH fetch --all
  if [ "$?" != "0" ]; then
    exit 1
  fi
}

function checkEnvironmentVariables() {
  if [ "$LATEST_VERSION" == "" ]; then
    LATEST_VERSION=$($SCRIPT_DIR/git_latest_version_tag.sh)
  fi

  if [ "$GIT_PATH" == "" ]; then
    GIT_PATH=$(which git)
  fi

  if [ "$GH_PATH" == "" ]; then
    GH_PATH=$(which gh)
  fi

  if [ ! -x "$GH_PATH" ]; then
    echo "Error: GitHub CLI (gh) is not installed or not executable"
    echo "To install GitHub CLI:"
    echo "  - On macOS: brew install gh"
    echo "For other platforms, visit: https://github.com/cli/cli#installation"
    exit 1
  fi

  if [ "$PACKAGE_JSON_PATH" == "" ]; then
    root_path=$(git rev-parse --show-toplevel)
    PACKAGE_JSON_PATH=${root_path}/package.json
  fi

  if [ ! -f "$PACKAGE_JSON_PATH" ]; then
    echo "Error: package.json does not exist"
    exit 1
  fi

  if [ "$PR_SUFFIX" != "" ]; then
    PR_SUFFIX="-$PR_SUFFIX"
  fi
}

function update_package_json() {
  local version=$1
  local package_json_path=$2
  local updated_package_json=$(cat $package_json_path | jq --arg version $version '.version = $version')
  echo "$updated_package_json" > $package_json_path
}

function commit_package_json() {
  local package_json_path=$1
  $GIT_PATH add $package_json_path
  $GIT_PATH commit -m "chore: update package version to v$PREDICTED_VERSION"
  if [ "$?" != "0" ]; then
    exit 1
  fi
}

function update_repository() {
  local current_version=$(jq -r '.version' $PACKAGE_JSON_PATH)
  echo "Updating package.json version from $current_version to $PREDICTED_VERSION"
  update_package_json $PREDICTED_VERSION $PACKAGE_JSON_PATH 
  # if there are no changes, do not commit
  if [ "$($GIT_PATH diff --name-only $PACKAGE_JSON_PATH)" == "" ]; then
    echo "No changes to commit"
    return
  fi
  commit_package_json $PACKAGE_JSON_PATH
}

# make sure you are in the main branch
function checkout_main() {
  $GIT_PATH checkout main
  if [ "$?" != "0" ]; then
    echo "Error: Could not checkout main branch"
    exit 1
  fi
}

function get_pull_request_body() {
  local version=$1
  if [ "$PULL_REQUEST_BODY" == "" ]; then
    PULL_REQUEST_BODY="$($SCRIPT_DIR/jira_hotfix_pr_body.sh $version)"
  fi
  echo "$PULL_REQUEST_BODY"
}

function pull() {
  $GIT_PATH pull
  if [ "$?" != "0" ]; then
    echo "Error: Could not pull"
    exit 1
  fi
}

# create a new branch if it does not exist or switch to it if it does
function checkout_hotfix() {
  $GIT_PATH checkout hotfix/v$PREDICTED_VERSION$PR_SUFFIX || $GIT_PATH checkout -b hotfix/v$PREDICTED_VERSION$PR_SUFFIX
  if [ "$?" != "0" ]; then
    exit 1
  fi
}

# push the branch to the remote repository
function push() {
  $GIT_PATH push -u origin hotfix/v$PREDICTED_VERSION$PR_SUFFIX
  if [ "$?" != "0" ]; then
    exit 1
  fi
}

# create a pull request that targets the main branch if it does not exist
function pull_request_exists() {
  local branch=$1
  local target_branch=$2
  # use gh to check if the pull request exists
  local pull_request=$($GH_PATH pr list --base $target_branch --head $branch --json number --jq '.[0].number')
  if [ "$?" != "0" ]; then
    exit 1
  fi
  if [ "$pull_request" == "" ]; then
    echo "false"
  else
    echo "true"
  fi
}

function create_pull_request() {
  local branch=$1
  local target_branch=$2
  local title="$3"
  local body="$4"
  local draft="$5"
  if [ "$draft" == "true" ]; then
    draft="--draft"
  else
    draft=""
  fi
  # use gh to create the pull request
  $GH_PATH pr create --base $target_branch --head $branch --title "$title" --body "$body" $draft
}

function main() {
  checkEnvironmentVariables
  fetchAllRemoteBranches
  PREDICTED_VERSION=$(incrementPatchVersion $LATEST_VERSION)
  checkout_main
  pull
  checkout_hotfix
  update_repository
  push
  PULL_REQUEST_BODY=$(get_pull_request_body $PREDICTED_VERSION)
  
  if [ "$(pull_request_exists hotfix/v$PREDICTED_VERSION$PR_SUFFIX main)" == "false" ]; then
    create_pull_request hotfix/v$PREDICTED_VERSION$PR_SUFFIX main "hotfix v$PREDICTED_VERSION to main" "$(get_pull_request_body $PREDICTED_VERSION)" "$PREDICTED_VERSION"
    if [ "$?" != "0" ]; then
      exit 1
    fi
  fi
}

main