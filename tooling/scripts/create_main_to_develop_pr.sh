#!/bin/bash

# This script creates a pull request from main to develop after successful production deployment
# It will optionally auto-merge the PR using `auto_merge_pr.sh` and clean up the release/hotfix branch

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Initialize environment variables
if [ "$GIT_PATH" == "" ]; then
  GIT_PATH=$(which git)
fi

if [ "$GH_PATH" == "" ]; then
  GH_PATH=$(which gh)
fi

if [ "$GIT_FLOW_BRANCH_CMD" == "" ]; then
  GIT_FLOW_BRANCH_CMD=$SCRIPT_DIR/git_flow_branch.sh
fi

# Get branch names
develop_branch=$($GIT_FLOW_BRANCH_CMD develop)
main_branch=$($GIT_FLOW_BRANCH_CMD main)

function check_environment() {
  if [ ! -x "$GH_PATH" ]; then
    echo "Error: GitHub CLI (gh) is not installed or not executable" >&2
    exit 1
  fi

  if [ ! -x "$GIT_PATH" ]; then
    echo "Error: Git is not installed or not executable" >&2
    exit 1
  fi
}

function get_current_version() {
  # Get the current version from package.json
  local package_json_path=$(git rev-parse --show-toplevel)/package.json
  jq -r '.version' "$package_json_path"
}

function get_release_branch_name() {
  # Get the release/hotfix branch name from the current version
  local version=$1
  local branch_name=""
  
  # Check if there's a release branch for this version
  local release_branch="release/v$version"
  local hotfix_branch="hotfix/v$version"
  
  if git show-ref --verify --quiet refs/remotes/origin/$release_branch; then
    branch_name=$release_branch
  elif git show-ref --verify --quiet refs/remotes/origin/$hotfix_branch; then
    branch_name=$hotfix_branch
  fi
  
  echo "$branch_name"
}

function check_main_ahead_of_develop() {
  # Check if main is ahead of develop
  local main_commit=$(git rev-parse $main_branch)
  local develop_commit=$(git rev-parse $develop_branch)
  
  if git merge-base --is-ancestor $develop_commit $main_commit; then
    echo "true"
  else
    echo "false"
  fi
}

function create_main_to_develop_pr() {
  local version=$1
  local title="chore: sync main (v$version) to develop"
  local body="This PR syncs the changes from main branch (v$version) to develop branch.

This is an automated PR created after successful production deployment.

### Changes included:
- Version bump to v$version
- All changes that were deployed to production

### Auto-merge criteria:
- No merge conflicts
- All checks pass
- No review required (automated process)"

  # Create the PR
  $GH_PATH pr create \
    --base $develop_branch \
    --head $main_branch \
    --title "$title" \
    --body "$body" 
}

## Auto-merge helpers have been extracted to `auto_merge_pr.sh`

function cleanup_release_branch() {
  local branch_name=$1
  
  if [ -n "$branch_name" ]; then
    echo "Cleaning up release branch: $branch_name" >&2
    
    # Delete remote branch
    git push origin --delete "$branch_name" 2>/dev/null || echo "Remote branch $branch_name already deleted or doesn't exist" >&2
    
    # Delete local branch if it exists
    if git show-ref --verify --quiet refs/heads/"$branch_name"; then
      git branch -d "$branch_name" 2>/dev/null || echo "Local branch $branch_name could not be deleted" >&2
    fi
  fi
}

function main() {
  echo "Starting auto-merge process from main to develop..." >&2
  
  check_environment
  
  # Get current version
  local version=$(get_current_version)
  echo "Current version: $version" >&2
  
  # Get release branch name
  local release_branch=$(get_release_branch_name "$version")
  echo "Release branch: $release_branch" >&2
  
  # Check if main is ahead of develop
  # local main_ahead=$(check_main_ahead_of_develop)
  # if [ "$main_ahead" == "false" ]; then
  #   echo "Main is not ahead of develop. No sync needed."
  #   cleanup_release_branch "$release_branch"
  #   exit 0
  # fi
  
  # echo "Main is ahead of develop. Creating PR to sync changes..."

  
  # Create PR from main to develop
  create_main_to_develop_pr "$version"
  exit 0
}

main 