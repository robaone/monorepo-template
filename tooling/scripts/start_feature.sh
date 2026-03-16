#!/bin/bash

# This script prompts the user for a feature name and create a new branch 
# in the format of $prefix<ticketid>-<featurename> where <featurename> is skewer case

# This script is intended to be run from the root of the repository

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$GIT_PATH" == "" ]; then
  if [ -z "$(which git)" ]; then
    echo "git command not found. Please ensure that git is installed and in your PATH."
    exit 1
  fi
  GIT_PATH=$(which git)
fi
# prompt the user for a feature name
if [ "$FEATURE_NAME" == "" ]; then
  read -p "Enter a feature name: " FEATURE_NAME
fi
feature_name=$FEATURE_NAME

# read the config.json if it exists
if [ "$GIT_CONFIG_PATH" == "" ]; then
  GIT_CONFIG_PATH=~/.tooling/config.json
fi
if [ -f "$GIT_CONFIG_PATH" ]; then
  FEATURE_PREFIX=$(jq -r '.feature.prefix' "$GIT_CONFIG_PATH")
else
  FEATURE_PREFIX="feature/"
fi

if [ "$GIT_FLOW_BRANCH_CMD" == "" ]; then
  GIT_FLOW_BRANCH_CMD=$SOURCE_DIR/git_flow_branch.sh
fi

# prompt the user for a ticket id
if [ "$TICKET_ID" == "" ]; then
  read -p "Enter a ticket id: " TICKET_ID
fi

function validate_ticket_id {
  local trello_pattern="https://trello.com/c/[a-zA-Z0-9]+"
  if [[ $1 =~ $trello_pattern ]]; then
    local suffix=$(echo $1 | sed 's/https:\/\/trello[.]com\/c\///')
    if [ "$suffix" == "" ]; then
      echo "Error: failed to extract ticket id from $1" >&2
      return 1
    fi
    echo "TRELLO-$suffix"
  elif [ "$1" == "" ]; then
    echo "NA"
  else
    echo $1
  fi
}

function get_flow_branch_name {
  local step=$1
  $GIT_FLOW_BRANCH_CMD $step
}

ticket_id=$(validate_ticket_id $TICKET_ID)

# create a new branch in the format of $FEATURE_PREFIX<ticketid>-<featurename> where <featurename> is skewer case
skewer_case_feature_name=$(echo "$feature_name" | sed 's/ /-/g' | tr '[:upper:]' '[:lower:]')
if [ "$?" != "0" ]; then
  echo "Error: failed to convert feature name to skewer case"
  exit 1
fi

branch_name="$FEATURE_PREFIX${ticket_id}-${skewer_case_feature_name}"

MATCHING_BRANCH="$($GIT_PATH branch -r | grep "${branch_name}$")"
if [ "$MATCHING_BRANCH" != "" ]; then
  echo "Branch $branch_name already exists. Please choose a different feature name or ticket id."
  exit 1
fi

develop_branch=$(get_flow_branch_name "develop")

$GIT_PATH checkout $develop_branch && \
$GIT_PATH pull && \
$GIT_PATH checkout -b $branch_name
exit $?
