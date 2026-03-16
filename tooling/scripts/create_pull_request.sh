#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$GIT_FLOW_CONFIG_FILE" == "" ]; then
  # get git repo root folder
  GIT_REPO_ROOT=$(git rev-parse --show-toplevel)
  export GIT_FLOW_CONFIG_FILE=$GIT_REPO_ROOT/.git-flow.json
fi

if [ "$SCRIPT_PATH" == "" ]; then
  SCRIPT_PATH=$SCRIPT_DIR/gh_create_pull_request.sh
fi

if [ "$GIT_PATH" == "" ]; then
  GIT_PATH=$(which git)
fi

if [ "$GIFS_FILE" == "" ]; then
  GIFS_FILE=$SCRIPT_DIR/config/pull_request_gifs.json
fi

function set_pr_title() {
  if [ "$1" == "" ] && [ "$PR_TITLE" == "" ]; then
    read -p "Enter pull request title: " PR_TITLE
    while [ -z "$PR_TITLE" ]; do
      read -p "Title cannot be empty. Please enter a pull request title: " PR_TITLE
    done
  fi
}

function choose_pr_type() {
  # check to see if the PR_TITLE starts with 'feat:', 'fix:', 'chore:', 'docs:', 'style:', 'refactor:', 'perf:', 'test:'
  if [[ "$PR_TITLE" =~ ^(feat:|fix:|chore:|docs:|style:|refactor:|perf:|test:).*$ ]]; then
    echo "PR title is valid"
  else
    # ask user to choose a type
    echo "PR title must start with one of the following types: feat:, fix:, chore:, docs:, style:, refactor:, perf:, test:"
    echo "Please choose a type:"
    echo "  (1) feat, (2) fix, (3) chore, (4) docs, (5) style, (6) refactor, (7) perf, (8) test"
    if [ "$PR_TYPE" == "" ]; then
      read -p "Enter a number: " PR_TYPE
      while [ -z "$PR_TYPE" ] || [[ ! "$PR_TYPE" =~ ^[1-8]$ ]]; do
        read -p "Invalid input. Please enter a number: " PR_TYPE
      done
    fi
    # add the type as a prefix to PR_TITLE
    case $PR_TYPE in
      1) PR_TITLE="feat: $PR_TITLE" ;;
      2) PR_TITLE="fix: $PR_TITLE" ;;
      3) PR_TITLE="chore: $PR_TITLE" ;;
      4) PR_TITLE="docs: $PR_TITLE" ;;
      5) PR_TITLE="style: $PR_TITLE" ;;
      6) PR_TITLE="refactor: $PR_TITLE" ;;
      7) PR_TITLE="perf: $PR_TITLE" ;;
      8) PR_TITLE="test: $PR_TITLE" ;;
    esac
  fi
}

function is_partial_implementation() {
  if [ "$PARTIAL_IMPLEMENTATION" == "" ]; then
    read -p "Is this a partial implementation? (y/n): " PARTIAL_IMPLEMENTATION
    while [ -z "$PARTIAL_IMPLEMENTATION" ] || [[ ! "$PARTIAL_IMPLEMENTATION" =~ ^[yn]$ ]]; do
      read -p "Invalid input. Please enter y or n: " PARTIAL_IMPLEMENTATION
    done
  fi
  if [ "$PARTIAL_IMPLEMENTATION" == "y" ]; then
    export PARTIAL_IMPLEMENTATION="true"
  else
    export PARTIAL_IMPLEMENTATION="false"
  fi
}

function extract_project_id() {
  local branch=$($GIT_PATH rev-parse --abbrev-ref HEAD) # current git branch
  local ticket_id=$(echo "$branch" | grep -oE '([A-Z]{2,}-[0-9]+)') # get Jira ticket ID from branch
  local project=default
  if [ "$ticket_id" != "" ]; then
    project=$(echo "$ticket_id" | cut -d'-' -f1) # get project from ticket id (project-123 -> project)
  fi
  echo $project
}

function gif_for_project() {
  local project=$1
  local gif="$(jq -r ".[\"$project\"]" $GIFS_FILE)"
  if [ "$gif" == "null" ]; then
    jq -r ".default" $GIFS_FILE
  else
    echo $gif
  fi
}

function create_pr() {
  GIF_URL=$(gif_for_project "$(extract_project_id)")
  $SCRIPT_PATH "${PR_TITLE:-}" "$GIF_URL" "$PARTIAL_IMPLEMENTATION"
}

function main() {
  set_pr_title "$1"
  choose_pr_type
  is_partial_implementation
  create_pr "$1" "$2"
}

main "$1" "$2"
