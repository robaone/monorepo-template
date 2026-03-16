#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$FINISH_FEATURE_CMD" == "" ]; then
  FINISH_FEATURE_CMD="$SCRIPT_DIR/git_finish_feature.sh"
fi

if [ "$GIT_FLOW_BRANCH_CMD" == "" ]; then
  GIT_FLOW_BRANCH_CMD=$SCRIPT_DIR/git_flow_branch.sh
fi

# load ~/.tooling/config.json if it exists
if [ -f ~/.tooling/config.json ]; then
  FEATURE_PREFIX=$(jq -r '.feature.prefix' ~/.tooling/config.json)
else
  FEATURE_PREFIX="feature/"
fi

develop_branch=$($GIT_FLOW_BRANCH_CMD develop)

function get_current_branch() {
  git symbolic-ref --short HEAD 2>/dev/null
}

function check_branch() {
  if [ "$FEATURE_PREFIX" == "" ]; then
    return 0
  fi
  if [[ "$(get_current_branch)" =~ ^($FEATURE_PREFIX) ]] || [[ "$(get_current_branch)" =~ ^(fix/) ]] || [[ "$(get_current_branch)" =~ [A-Z]+-[0-9]+ ]]; then
    return 0
  else
    echo "ERROR: You must be in a feature or fix branch"
    return 1
  fi
}

check_branch
if [ "$?" != "0" ]; then
  exit 1
fi

function get_pr_number() {
  local branch=$1
  gh pr list --base $develop_branch --head "$branch" | grep "$branch" | awk '{print $1}'
}

function merge_to_develop() {
  local pr_number=$1
  gh pr merge $pr_number --squash

}

function delete_branch() {
  $FINISH_FEATURE_CMD
}

merge_to_develop $(get_pr_number "$(get_current_branch)")

if [ "$?" == "0" ]; then
  #  prompt to delete the branch using the git_finish_feature.sh script
    echo "Branch $(get_current_branch) has been merged to $develop_branch"
    echo "Do you want to delete the local branch? (y/n)"
    read answer
    if [ "$answer" == "y" ]; then
      delete_branch
    fi
fi

