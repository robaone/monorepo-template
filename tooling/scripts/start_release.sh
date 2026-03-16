#!/bin/bash

# This script to create a release branch if it does not exist by using
# the next predicted version.
# It will push the branch to the remote repository and
# create a pull request that targets the main branch only.
# After successful production deployment, a workflow will automatically
# create a PR from main to develop and merge it if there are no conflicts.

function init_script() {
  # Initialize or calculate necessary variables
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

  if [ "$PREDICTED_VERSION" == "" ]; then
    PREDICTED_VERSION=$($SCRIPT_DIR/git_predict_next_version.sh)
  fi

  if [ "$PACKAGE_JSON_PATH" == "" ]; then
    root_path=$(git rev-parse --show-toplevel)
    PACKAGE_JSON_PATH=${root_path}/package.json
  fi

  if [ "$GIT_PATH" == "" ]; then
    GIT_PATH=$(which git)
  fi

  if [ "$GH_PATH" == "" ]; then
    GH_PATH=$(which gh)
  fi

  if [ "$PULL_REQUEST_BODY_PATH" == "" ]; then
    PULL_REQUEST_BODY_PATH="$SCRIPT_DIR/jira_release_pr_body.sh"
  fi

  if [ "$GIT_FLOW_BRANCH_CMD" == "" ]; then
    GIT_FLOW_BRANCH_CMD=$SCRIPT_DIR/git_flow_branch.sh
  fi

  develop_branch=$($GIT_FLOW_BRANCH_CMD develop)
  main_branch=$($GIT_FLOW_BRANCH_CMD main)

  if [ ! -f "$PACKAGE_JSON_PATH" ]; then
    echo "Error: package.json does not exist"
    exit 1
  fi
}

function create_branch() {
  $GIT_PATH checkout $develop_branch
  if [ "$?" != "0" ]; then
    echo "Error: Could not checkout $develop_branch"
    exit 1
  fi
  $GIT_PATH pull
  $GIT_PATH checkout release/v$PREDICTED_VERSION || $GIT_PATH checkout -b release/v$PREDICTED_VERSION
  if [ "$?" != "0" ]; then
    exit 1
  fi
}

function push_branch() {
  $GIT_PATH push -u origin release/v$PREDICTED_VERSION
  if [ "$?" != "0" ]; then
    exit 1
  fi
}

function pull_request_exists() {
  local branch=$1
  local target_branch=$2
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
  $GH_PATH pr create --base $target_branch --head $branch --title "$title" --body "$body" $draft
}

function get_package_json() {
  local package_json_path=$1
  local package_json=$(cat $package_json_path)
  echo $package_json
}

function update_package_version() {
  local version=$1
  local package_json_path=$2
  local package_json=$(get_package_json $package_json_path)
  local updated_package_json=$(echo $package_json | jq --arg version $version '.version = $version')
  echo "$updated_package_json" > $package_json_path
}

function commit_package_json() {
  local package_json_path=$1
  local package_json=$(get_package_json $package_json_path)
  $GIT_PATH add $package_json_path
  $GIT_PATH commit -m "chore: update package version to v$PREDICTED_VERSION"
  if [ "$?" != "0" ]; then
    exit 1
  fi
}

function pull_main() {
  local main_branch=$1
  $GIT_PATH checkout $main_branch
  if [ "$?" != "0" ]; then
    echo "Error: Could not checkout $main_branch"
    exit 1
  fi
  $GIT_PATH pull
}

function fetch_all_changes() {
  $GIT_PATH fetch --all
}

function update_repository() {
  local current_version=$(get_package_json $PACKAGE_JSON_PATH | jq -r '.version')
  if [ "$current_version" != "$PREDICTED_VERSION" ]; then
    echo "Updating package.json version from $current_version to $PREDICTED_VERSION"
    update_package_version $PREDICTED_VERSION $PACKAGE_JSON_PATH && commit_package_json $PACKAGE_JSON_PATH
  fi
}

function main() {
  init_script
  pull_main 
  fetch_all_changes
  create_branch
  update_repository
  push_branch
  
  if [ "$(pull_request_exists release/v$PREDICTED_VERSION $main_branch)" == "false" ]; then
    create_pull_request release/v$PREDICTED_VERSION $main_branch "release v$PREDICTED_VERSION to $main_branch" "$($PULL_REQUEST_BODY_PATH)"
    if [ "$?" != "0" ]; then
      exit 1
    fi
  fi
}

main