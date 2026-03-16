#!/bin/bash

if [ "$GIT_PATH" == "" ]; then
  if [ -z "$(which git)" ]; then
    echo "git command not found. Please ensure that git is installed and in your PATH."
    exit 1
  fi
  GIT_PATH=$(which git)
fi

function git_repo_root_path {
  $GIT_PATH rev-parse --show-toplevel
}

function get_flow_branch_name {
  local step=$1
  local root_path=$(git_repo_root_path)
  if [ "$root_path" == "" ]; then
    echo "Error: failed to get the root path of the repository" >&2
    return 1
  fi
  if [ ! -f "$root_path/.git-flow.json" ]; then
    echo "$step"
  elif [ -z "$(jq -r '.git.'$step'' $root_path/.git-flow.json)" ]; then
    echo "$step"
  else
    jq -r '.git.'$step'' $root_path/.git-flow.json
  fi
}

if [ "$1" != "develop" ] && [ "$1" != "main" ]; then
  echo "Usage: [develop|main]"
  exit 1
fi

get_flow_branch_name $1