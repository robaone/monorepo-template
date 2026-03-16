#!/bin/bash
set -e

function get_current_branch() {
  git symbolic-ref --short HEAD 2>/dev/null
}

function check_branch() {
  if [[ "$(get_current_branch)" =~ ^(release/|hotfix/) ]]; then
    return 0
  else
    echo "ERROR: You must be in a release or hotfix branch"
    return 1
  fi
}

check_branch
if [ "$?" != "0" ]; then
  exit 1
fi

function get_pr_number() {
  local branch=$1
  local branch_prefix=$(echo $branch | cut -d'/' -f1)
  gh pr list --base develop --head "$branch" | grep "$branch_prefix" | awk '{print $1}'
}

function merge_to_develop() {
  local pr_number=$1
  gh pr merge $pr_number --merge
}

function delete_branch() {
  local branch=$1
  git branch -d "$branch"
}

function checkout_develop_and_delete_branch() {
  local branch=$1
  local proceed=$2
  git checkout develop && git pull
  # ask to delete the branch
  if [ "$proceed" == "true" ]; then
    delete_branch "$branch"
  else
    read -p "Do you want to delete the local branch? (y/n) " -n 1 -r DELETE_BRANCH
    if [[ $DELETE_BRANCH =~ ^[Yy]$ ]]; then
      echo ""
      delete_branch "$branch"
    fi
  fi
}

current_branch=$(get_current_branch)
pr_number=$(get_pr_number "$current_branch")
if [ "$pr_number" == "" ]; then
  echo "ERROR: No PR found for branch $current_branch"
  # prompt to delete the branch
  read -p "Do you want to delete the local branch? (y/n) " -n 1 -r DELETE_BRANCH
  echo ""
  if [[ ! $DELETE_BRANCH =~ ^[Yy]$ ]]; then
    echo "No action taken"
    exit 0
  else
    checkout_develop_and_delete_branch "$current_branch" "true"
  fi
fi
merge_to_develop "$pr_number"
checkout_develop_and_delete_branch "$current_branch"
