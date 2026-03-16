#!/bin/bash

# Auto-merge a GitHub PR after waiting for checks and ensuring it's mergeable.
# Usage: ./auto_merge_pr.sh <pr_url_or_number>

set -e

# Initialize environment variables
if [ "$GH_PATH" == "" ]; then
  GH_PATH=$(which gh)
fi

function check_environment() {
  if [ ! -x "$GH_PATH" ]; then
    echo "Error: GitHub CLI (gh) is not installed or not executable"
    exit 1
  fi
}

function parse_pr_number() {
  local input="$1"
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    echo "$input"
    return 0
  fi
  # Extract number from .../pull/<number>
  echo "$input" | sed 's/.*\/pull\///'
}

function check_pr_mergeable() {
  local pr_number="$1"

  # Wait for checks to complete (max 5 minutes)
  local max_attempts=30
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    local mergeable=$($GH_PATH pr view "$pr_number" --json mergeable --jq '.mergeable')

    if [ "$mergeable" == "MERGEABLE" ]; then
      echo "true"
      return 0
    elif [ "$mergeable" == "CONFLICTING" ]; then
      echo "false"
      return 0
    fi

    echo "Waiting for PR checks to complete... (attempt $attempt/$max_attempts)"
    sleep 10
    attempt=$((attempt + 1))
  done

  echo "timeout"
}

function auto_merge_pr() {
  local pr_number="$1"
  echo "Auto-merging PR #$pr_number..."
  $GH_PATH pr merge "$pr_number" --merge
}

function main() {
  if [ $# -lt 1 ]; then
    echo "Usage: $0 <pr_url_or_number>"
    exit 1
  fi

  check_environment

  local pr_input="$1"
  local pr_number=$(parse_pr_number "$pr_input")

  if [ -z "$pr_number" ]; then
    echo "Error: Could not parse PR number from input: $pr_input"
    exit 1
  fi

  local mergeable=$(check_pr_mergeable "$pr_number")

  if [ "$mergeable" == "true" ]; then
    if auto_merge_pr "$pr_number"; then
      echo "Successfully merged PR #$pr_number"
      exit 0
    else
      echo "Failed to merge PR #$pr_number"
      exit 1
    fi
  elif [ "$mergeable" == "false" ]; then
    echo "PR #$pr_number has conflicts. Manual intervention required."
    exit 2
  else
    echo "Timeout waiting for PR checks for #$pr_number. Manual intervention required."
    exit 3
  fi
}

main "$@"


