#!/bin/bash

# configuration
set -e

if [ "$EVENT" != "pull_request" ]; then
  echo "Not applicable"
  exit 0
fi
if [ "$PACKAGE_PATH" == "" ]; then
  PACKAGE_PATH=.
fi
if [ "$SCRIPT_PATH" == "" ]; then
  SCRIPT_PATH=$(dirname $BASH_SOURCE)
fi
if [ "$JQ_PATH" == "" ]; then
  JQ_PATH=$(which jq)
  if [ -z "$JQ_PATH" ]; then
    echo "jq is not installed"
    exit 1
  fi
fi
if [ "$GIT_PATH" == "" ]; then
  GIT_PATH=$(which git)
  if [ -z "$GIT_PATH" ]; then
    echo "git is not installed"
    exit 1
  fi
fi
if [ "$FIGLET_PATH" == "" ]; then
  FIGLET_PATH=$(which figlet)
  if [ -z "$FIGLET_PATH" ]; then
    echo "figlet is not installed"
    exit 1
  fi
fi

function getMajorVersionNumber() {
  local version=$1
  echo $version | sed -E 's/^([0-9]+)\..*/\1/'
}
function getMinorVersionNumber() {
  local version=$1
  echo $version | sed -E 's/^[0-9]+\.([0-9]+)\..*/\1/'
}
function getPatchVersionNumber() {
  local version=$1
  echo $version | sed -E 's/^[0-9]+\.[0-9]+\.([0-9]+).*/\1/'
}
function getBranchInfo() {
  if [ "$CURRENT_BRANCH" == "" ]; then
    $GIT_PATH rev-parse --abbrev-ref HEAD;
  else
    echo $CURRENT_BRANCH;
  fi
}
function checkTargetBranch() {
  PARSED_BRANCH_VERSION=$(echo $1 | sed -E 's/(release|hotfix)\/v//')
  if [ "$TARGET_BRANCH" == "" ]; then
    echo "Target branch is not specified in TARGET_BRANCH environment variable"
    exit 1
  fi
  if [ "$TARGET_BRANCH" != "main" ]; then
    echo "Nothing to do here"
    exit 0
  fi
}
function getPackageVersion() {
  $JQ_PATH -r .version $1/package.json
}
function getNextPredictedRelease() {
  if [ "$NEXT_PREDICTED_RELEASE" == "" ]; then
    $SCRIPT_PATH/git_predict_next_version.sh
  else
    echo $NEXT_PREDICTED_RELEASE
  fi
}
function comparePredictedReleaseToPackageVersion() {
  if [ "$1" != "$2" ]; then
    echo "Error: Version mismatch detected!"
    echo "Expected Release Version: $1"
    echo "Current Package Version:  $2"
    echo "
Action Required:
1. Update the version in package.json to match the release version
2. Commit the changes and push to your branch"
    exit 1
  else
    echo "Everything is good.  Ready to release"
    $FIGLET_PATH "version $1"
  fi
}
function checkForPatchVersion() {
  if [ $(getPatchVersionNumber $1) == 0 ]; then
    echo "Error: The hotfix branch indicates a minor release, but a patch release is expected.
Action: Ensure the branch name follows the patch release convention (e.g., hotfix/v1.0.x)."
    exit 1
  fi
}
function main() {
  BRANCH_NAME=$(getBranchInfo)
  checkTargetBranch $BRANCH_NAME
  PACKAGE_VERSION=$(getPackageVersion $PACKAGE_PATH)
  NEXT_PREDICTED_RELEASE=$(getNextPredictedRelease)
  if [[ $BRANCH_NAME =~ hotfix/v.* ]]; then
    checkForPatchVersion $NEXT_PREDICTED_RELEASE
  fi
  comparePredictedReleaseToPackageVersion $NEXT_PREDICTED_RELEASE $PACKAGE_VERSION
}
main

