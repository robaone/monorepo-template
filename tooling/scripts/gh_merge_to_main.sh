#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$GIT_FLOW_BRANCH_CMD" == "" ]; then
  GIT_FLOW_BRANCH_CMD=$SCRIPT_DIR/git_flow_branch.sh
fi
if [ "$GH_CMD" == "" ]; then
  GH_CMD=gh
fi
if [ "$GIT_CMD" == "" ]; then
  GIT_CMD=git
fi

main_branch=$($GIT_FLOW_BRANCH_CMD main)

function get_current_branch() {
  $GIT_CMD symbolic-ref --short HEAD 2>/dev/null
}

function check_branch() {
  local current_branch=$1
  if [[ "$current_branch" =~ ^(release/|hotfix/) ]]; then
    return 0
  else
    echo "ERROR: You must be in a release or hotfix branch"
    return 1
  fi
}

function get_commit_count_in_pr() {
  local pr_number=$1
  $GH_CMD pr view $pr_number --json number --json commits --json state --json title | jq '.commits | length'
}

current_branch=$(get_current_branch)
if [ "$current_branch" == "" ]; then
  echo "ERROR: Could not get the current branch"
  exit 1
fi
check_branch "$current_branch"
if [ "$?" != "0" ]; then
  exit 1
fi

function get_pr_number() {
  local branch=$1
  local branch_prefix=$(echo $branch | cut -d'/' -f1)
  $GH_CMD pr list --base $main_branch --head "$branch" | grep "$branch_prefix" | awk '{print $1}'
}

function pr_status() {
  local pr_number=$1
  # Get last workflow run for the PR
  local workflow_run=$($GH_CMD run list | grep "$current_branch" | grep "$main_branch" | head -n 1 | awk '{print $1}')
  if [ "$workflow_run" == "" ]; then
    echo "No workflow run found for branch $current_branch"
    exit 1
  fi
  # Get the status of the workflow run
  if [ "$workflow_run" == "✓" ] || [ "$workflow_run" == "completed" ]; then
    echo "ready"
  else
    echo "workflow run failed"
  fi
}

function merge_main_into_branch() {
  $GIT_CMD fetch origin
  $GIT_CMD merge origin/main
  local status_output=$($GIT_CMD status)
  if [[ "$status_output" == *"Your branch is up to date"* ]] && [[ "$status_output" == *"nothing to commit, working tree clean"* ]]; then
    echo "Branch is up to date with main"
  else
    echo "Branch is not up to date with main"
    exit 1
  fi
}

function get_first_commit_hash() {
  local pr_number=$1
  $GH_CMD pr view $pr_number --json commits --jq '.commits[0].oid'
}

function squash_commits() {
  # squash commits for this pr
  local pr_number=$1
  local first_commit_hash=$(get_first_commit_hash $pr_number)

  # Get the line number of the first commit hash in the git log
  local line_number=$($GIT_CMD log --pretty=format:"%H" origin/$main_branch..HEAD | grep -n "." | tail -n 1 | cut -d: -f1)
  
  if [ -z "$line_number" ]; then
    echo "First commit hash not found in git log."
    exit 1
  fi

  if [ "$SQUASH_COMMITS" == "" ]; then
    echo "We are about to run git rebase -i HEAD~$((line_number))"
    read -p "Press enter to continue or Ctrl+C to cancel" -n 1 -r
  fi
  # Start an interactive rebase from the parent of the first commit
  $GIT_CMD rebase -i HEAD~$((line_number))
  if [ "$?" != "0" ]; then
    echo "Error during interactive rebase"
    exit 1
  fi

  if [ "$SQUASH_COMMITS" == "" ]; then
    read -p "Do you want to push the changes? (y/n) " push
  fi
  if [ "$push" == "y" ] || [ "$SQUASH_COMMITS" == "true" ]; then
    $GIT_CMD push origin $current_branch --force
    echo "You must wait for all checks to pass before merging the PR"
  else
    echo "No action taken"
  fi
}

function merge_to_main() {
  local pr_number=$1
  $GH_CMD pr merge $pr_number --merge
}

function main() {
  merge_main_into_branch
  local pr_number=$(get_pr_number "$current_branch")
  local ready_to_merge=$(pr_status)
  if [ "$ready_to_merge" != "ready" ]; then
    echo "You must wait for all checks to pass before merging the PR"
    $GH_CMD run list
    exit 1
  fi
  if [ "$pr_number" != "" ]; then
    local commit_count=$(get_commit_count_in_pr $pr_number)
    if [ "$commit_count" == "1" ] || [[ "$current_branch" == "release/"* ]]; then
      merge_to_main $pr_number
    else
      echo "The PR must have only one commit"
      if [ "$SQUASH_COMMITS" == "" ]; then
        read -p "Do you want to squash the commits? (y/n) " squash
      fi
      if [ "$squash" == "y" ] || [ "$SQUASH_COMMITS" == "true" ]; then
        squash_commits
        exit 0
      else
        read -p "Do you want to merge anyway? (y/n) " merge
        if [ "$merge" == "y" ]; then
          merge_to_main $pr_number
        else
          echo "No action taken"
          exit 0
        fi
      fi
    fi
  else
    echo "The PR number could not be found"
    exit 1
  fi
}

main