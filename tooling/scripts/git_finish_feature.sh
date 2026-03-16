#!/bin/bash

if [ "$SCRIPT_DIR" == "" ]; then
  SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
fi

if [ "$1" == "-f" ]; then
  FORCE=true
fi

if [ "$GIT_FLOW_BRANCH_CMD" == "" ]; then
  GIT_FLOW_BRANCH_CMD=$SCRIPT_DIR/git_flow_branch.sh
fi
develop_branch=$($GIT_FLOW_BRANCH_CMD develop)
main_branch=$($GIT_FLOW_BRANCH_CMD main)

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$CURRENT_BRANCH" == "$main_branch" ]; then
  echo "You are on main branch. Please checkout a feature branch first."
  exit 1
elif [ "$CURRENT_BRANCH" == "$develop_branch" ]; then
  echo "You are on $develop_branch branch. Please checkout a feature branch first."
  exit 1
elif [[ $CURRENT_BRANCH == release/* ]]; then
  echo "You are on a release branch. Please checkout a feature branch first."
  exit 1
elif [[ $CURRENT_BRANCH == hotfix/* ]]; then
  echo "You are on a hotfix branch. Please checkout a feature branch first."
  exit 1
fi

PR_STATUS=$(gh pr view --json "closed,state,mergedBy,url")
PR_STATE=$(echo $PR_STATUS | jq -r '.closed')
if [ "$PR_STATE" != "true" ]; then
  echo "PR is not closed. Please close the PR first."
  echo "PR URL: $(echo $PR_STATUS | jq -r '.url')"
  exit 1
fi
echo "PR is closed.  It was $(echo $PR_STATUS | jq -r '.state' | tr '[:upper:]' '[:lower:]') by $(echo $PR_STATUS | jq -r '.mergedBy.name')."
if [ "$FORCE" == "true" ]; then
  git checkout $develop_branch && git pull && git branch -D $CURRENT_BRANCH
else
  git checkout $develop_branch && git pull && git branch -d $CURRENT_BRANCH
fi
