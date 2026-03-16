#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Parse command line arguments
SIMPLE_MODE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --simple)
      SIMPLE_MODE=true
      shift
      ;;
    --silent)
      SILENT=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--simple] [--silent]"
      exit 1
      ;;
  esac
done

$SCRIPT_DIR/gh_check.sh

if [ "$GIT_CMD" == "" ]; then
  GIT_CMD=$(which git)
fi

if [ "$GH_CMD" == "" ]; then
  GH_CMD=$(which gh)
fi

if [ "$MERGE_FEATURE_TO_DEVELOP_CMD" == "" ]; then
  MERGE_FEATURE_TO_DEVELOP_CMD=$SCRIPT_DIR/gh_merge_feature_to_develop.sh
fi

if [ "$MERGE_RELEASE_TO_DEVELOP_CMD" == "" ]; then
  MERGE_RELEASE_TO_DEVELOP_CMD=$SCRIPT_DIR/gh_merge_to_develop.sh
fi

if [ "$MERGE_RELEASE_TO_MAIN_CMD" == "" ]; then
  MERGE_RELEASE_TO_MAIN_CMD=$SCRIPT_DIR/gh_merge_to_main.sh
fi

if [ "$WATCH_WORKFLOW_CMD" == "" ]; then
  WATCH_WORKFLOW_CMD=$SCRIPT_DIR/gh_watch_workflow.sh
fi

if [ "$GIT_FLOW_BRANCH_CMD" == "" ]; then
  GIT_FLOW_BRANCH_CMD=$SCRIPT_DIR/git_flow_branch.sh
fi

# Get the configured branch names from .git-flow.json
DEVELOP_BRANCH=$($GIT_FLOW_BRANCH_CMD develop)
MAIN_BRANCH=$($GIT_FLOW_BRANCH_CMD main)

function get_branch_name() {
  $GIT_CMD branch --show-current
}

function check_uncommitted_changes() {
  local changes=""
  local has_changes=0
  
  # Check for untracked files
  local untracked=$($GIT_CMD status --porcelain | grep "^??" || echo "")
  if [ "$untracked" != "" ]; then
    changes="Untracked files:"
    while read -r line; do
      changes="${changes}\n  ${line}"
    done <<< "$untracked"
    changes="${changes}\n"
    has_changes=1
  fi
  
  # Check for modified files
  local modified=$($GIT_CMD status --porcelain | grep "^ M" || echo "")
  if [ "$modified" != "" ]; then
    changes="${changes}Modified files:"
    while read -r line; do
      changes="${changes}\n  ${line}"
    done <<< "$modified"
    changes="${changes}\n"
    has_changes=1
  fi
  
  # Check for deleted files
  local deleted=$($GIT_CMD status --porcelain | grep "^ D" || echo "")
  if [ "$deleted" != "" ]; then
    changes="${changes}Deleted files:"
    while read -r line; do
      changes="${changes}\n  ${line}"
    done <<< "$deleted"
    changes="${changes}\n"
    has_changes=1
  fi
  
  # Check for staged changes
  local staged=$($GIT_CMD status --porcelain | grep "^[AMDR]" || echo "")
  if [ "$staged" != "" ]; then
    changes="${changes}Staged changes:"
    while read -r line; do
      changes="${changes}\n  ${line}"
    done <<< "$staged"
    changes="${changes}\n"
    has_changes=1
  fi
  
  echo -e "$changes"
  return $has_changes
}

function check_unmerged_changes() {
  local branch_name=$1
  local target_branch=$2
  local unmerged_changes=""
  
  # Get the merge base between the current branch and target branch
  local merge_base=$($GIT_CMD merge-base $target_branch $branch_name 2>/dev/null || echo "")
  
  if [ "$merge_base" == "" ]; then
    unmerged_changes="NO_MERGE_BASE"
  else
    # Get commits that are in the current branch but not in the target branch
    unmerged_changes=$($GIT_CMD log --oneline $merge_base..$branch_name 2>/dev/null || echo "")
  fi
  
  echo "$unmerged_changes"
}

function get_pr_info() {
  local branch_name=$1
  local target_branch=$2
  local prs
  local pr_info=""

  if ! prs=$($GH_CMD pr list --json number,baseRefName,headRefName,mergeable,mergeStateStatus,reviewDecision,url --state open); then
    echo "Error: Failed to fetch pull requests" >&2
    return 1
  fi

  pr_info=$(echo "$prs" | jq -c '.[] | select(.headRefName == "'"$branch_name"'") | select(.baseRefName == "'"$target_branch"'")')
  echo "$pr_info"
}

function check_pr_status() {
  local pr_info=$1
  local status=""
  
  if [ "$pr_info" == "" ]; then
    status="NO_PR"
  else
    local mergeable=$(echo "$pr_info" | jq -r '.mergeable')
    local merge_state=$(echo "$pr_info" | jq -r '.mergeStateStatus')
    local review_decision=$(echo "$pr_info" | jq -r '.reviewDecision')
    
    if [ "$mergeable" == "null" ]; then
      status="CHECKING"
    elif [ "$mergeable" == "false" ]; then
      status="CONFLICTS"
    elif [ "$merge_state" == "BLOCKED" ]; then
      status="BLOCKED"
    elif [ "$review_decision" == "CHANGES_REQUESTED" ]; then
      status="CHANGES_NEEDED"
    elif [ "$review_decision" == "APPROVED" ]; then
      status="READY"
    else
      status="PENDING_REVIEW"
    fi
  fi
  
  echo "$status"
}

function get_workflow_step() {
  local branch_name=$1
  if [[ "$branch_name" == "release/v"* ]] || [[ "$branch_name" == "hotfix/v"* ]]; then
    echo "release_to_main"
  elif [ "$branch_name" != "$DEVELOP_BRANCH" ] && [ "$branch_name" != "$MAIN_BRANCH" ]; then
    echo "feature_to_develop"
  else
    echo "$branch_name"
  fi
}

function check_pr_to_main_open() {
  local prs
  local pr_to_main_open=false
  local open_pr
  local branch_name

  branch_name=$1
  if ! prs=$($GH_CMD pr list --json number,baseRefName,headRefName --state open); then
    echo "Error: Failed to fetch pull requests" >&2
    return 1
  fi

  open_pr=$(echo "$prs" | jq -c '.[] | select(.headRefName == "'"$branch_name"'") | select(.baseRefName == "'"$MAIN_BRANCH"'")')
  if [ "$open_pr" != "" ]; then
    pr_to_main_open=true
  fi
  echo "$pr_to_main_open"
}

function merge_feature_to_develop() {
  echo "Executing feature to develop merge..."
  $MERGE_FEATURE_TO_DEVELOP_CMD
}

function merge_release_to_develop() {
  echo "Executing release to develop merge..."
  $MERGE_RELEASE_TO_DEVELOP_CMD
}

function merge_release_to_main() {
  echo "Executing release to main merge..."
  $MERGE_RELEASE_TO_MAIN_CMD
}

function simple_merge() {
  local current_branch=$1
  # Use the configured develop branch from .git-flow.json
  local default_branch=$DEVELOP_BRANCH
  
  echo "Executing simple merge..."
  echo "Current branch: $current_branch"
  echo "Default branch: $default_branch"
  
  # Check if we're already on the default branch
  if [ "$current_branch" == "$default_branch" ]; then
    echo "Already on default branch ($default_branch). No action needed."
    return 0
  fi
  
  # Execute the simple merge sequence
  echo "Switching to $default_branch and pulling latest changes..."
  $GIT_CMD checkout "$default_branch" && $GIT_CMD pull
  
  echo "Deleting local branch: $current_branch"
  $GIT_CMD branch -d "$current_branch"
  
  echo "Simple merge completed successfully!"
}

function watch_workflow_run() {
  if [ "$WATCH_WORKFLOW" == "y" ]; then
    echo "Watching workflow execution..."
    $WATCH_WORKFLOW_CMD
  fi
}

function display_analysis() {
  local branch_name=$1
  local workflow_step=$2
  local pr_to_main_info=$3
  local pr_to_develop_info=$4
  local unmerged_to_main=$5
  local unmerged_to_develop=$6
  local uncommitted_changes=$7

  echo "==========================================="
  echo "Branch Analysis Report"
  echo "==========================================="
  echo "Current branch: $branch_name"
  echo "Workflow step: $workflow_step"
  echo "-------------------------------------------"

  echo "Local Changes:"
  if [ "$uncommitted_changes" == "" ]; then
    echo "  - No uncommitted changes"
  else
    echo -e "$uncommitted_changes"
    echo "-------------------------------------------"
    echo "WARNING: You have uncommitted changes in your working directory."
    echo "Please either:"
    echo "  1. Commit your changes:"
    echo "     git add <files>"
    echo "     git commit -m \"your message\""
    echo "  2. Stash your changes:"
    echo "     git stash"
    echo "  3. Discard your changes:"
    echo "     git reset --hard"
    echo "-------------------------------------------"
    exit 1
  fi

  if [[ "$branch_name" == "release/v"* ]] || [[ "$branch_name" == "hotfix/v"* ]]; then
    local pr_to_main_status=$(check_pr_status "$pr_to_main_info")
    
    echo "Release/Hotfix Branch Status:"
    echo "  PR to $MAIN_BRANCH:"
    if [ "$pr_to_main_status" == "NO_PR" ]; then
      echo "    - No open PR to $MAIN_BRANCH"
    else
      local pr_url=$(echo "$pr_to_main_info" | jq -r '.url')
      echo "    - PR URL: $pr_url"
      echo "    - Status: $pr_to_main_status"
    fi
    
    echo "  Note: After successful production deployment, a workflow will automatically"
    echo "        create a PR from $MAIN_BRANCH to $DEVELOP_BRANCH and merge it if there are no conflicts."

    echo "  Unmerged Changes:"
    if [ "$unmerged_to_main" == "NO_MERGE_BASE" ]; then
      echo "    - No merge base with $MAIN_BRANCH branch"
    elif [ "$unmerged_to_main" == "" ]; then
      echo "    - No unmerged commits to $MAIN_BRANCH"
    else
      echo "    - Unmerged commits to $MAIN_BRANCH:"
      echo "$unmerged_to_main" | while read -r line; do
        echo "      $line"
      done
    fi
  else
    local pr_status=$(check_pr_status "$pr_to_develop_info")
    echo "Feature Branch Status:"
    if [ "$pr_status" == "NO_PR" ]; then
      echo "  - No open PR to $DEVELOP_BRANCH"
    else
      local pr_url=$(echo "$pr_to_develop_info" | jq -r '.url')
      echo "  - PR URL: $pr_url"
      echo "  - Status: $pr_status"
    fi

    echo "  Unmerged Changes:"
    if [ "$unmerged_to_develop" == "NO_MERGE_BASE" ]; then
      echo "    - No merge base with $DEVELOP_BRANCH branch"
    elif [ "$unmerged_to_develop" == "" ]; then
      echo "    - No unmerged commits to $DEVELOP_BRANCH"
    else
      echo "    - Unmerged commits to $DEVELOP_BRANCH:"
      echo "$unmerged_to_develop" | while read -r line; do
        echo "      $line"
      done
    fi
  fi

  echo "-------------------------------------------"
  echo "Available Actions:"
  
  if [[ "$branch_name" == "release/v"* ]] || [[ "$branch_name" == "hotfix/v"* ]]; then
    if [ "$pr_to_main_status" == "READY" ]; then
      echo "1. Merge release to $MAIN_BRANCH"
    else
      echo "No merges available - PR not ready"
      exit 1
    fi
  elif [ "$branch_name" != "$DEVELOP_BRANCH" ] && [ "$branch_name" != "$MAIN_BRANCH" ]; then
    if [ "$pr_status" == "READY" ]; then
      echo "1. Merge feature to $DEVELOP_BRANCH"
    else
      echo "No merges available - PR not ready"
      exit 1
    fi
  else
    echo "No valid merge paths available for branch: $branch_name"
    exit 1
  fi

  echo "2. Watch workflow after merge (optional)"
  echo "==========================================="
}

function main() {
  local branch_name="$(get_branch_name)"
  
  # Handle simple mode
  if [ "$SIMPLE_MODE" == "true" ]; then
    echo "==========================================="
    echo "Simple Merge Mode"
    echo "==========================================="
    echo "Current branch: $branch_name"
    echo "This will:"
    echo "  1. Switch to default branch"
    echo "  2. Pull latest changes"
    echo "  3. Delete the current branch ($branch_name)"
    echo "==========================================="
    
    if [ "$SILENT" != "true" ]; then
      read -p "Do you want to proceed with the simple merge? (y/n): " CONTINUE
      if [ "$CONTINUE" != "y" ]; then
        echo "No action taken"
        return 0
      fi
    fi
    
    simple_merge "$branch_name"
    return 0
  fi
  
  local workflow_step="$(get_workflow_step $branch_name)"

  if [ "$workflow_step" == "$DEVELOP_BRANCH" ] || [ "$workflow_step" == "$MAIN_BRANCH" ]; then
    echo "You cannot merge $branch_name"
    exit 1
  fi

  # Gather PR information upfront
  local pr_to_main_info=""
  local pr_to_develop_info=""
  local unmerged_to_main=""
  local unmerged_to_develop=""
  local uncommitted_changes="$(check_uncommitted_changes)"
  
  if [[ "$branch_name" == "release/v"* ]] || [[ "$branch_name" == "hotfix/v"* ]]; then
    pr_to_main_info=$(get_pr_info "$branch_name" "$MAIN_BRANCH")
    unmerged_to_main=$(check_unmerged_changes "$branch_name" "$MAIN_BRANCH")
  else
    pr_to_develop_info=$(get_pr_info "$branch_name" "$DEVELOP_BRANCH")
    unmerged_to_develop=$(check_unmerged_changes "$branch_name" "$DEVELOP_BRANCH")
  fi

  display_analysis "$branch_name" "$workflow_step" "$pr_to_main_info" "$pr_to_develop_info" "$unmerged_to_main" "$unmerged_to_develop" "$uncommitted_changes"

  if [ "$SILENT" != "true" ]; then
    read -p "Do you want to proceed with the merge? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
      echo "No action taken"
      return 0
    fi

    read -p "Do you want to watch the workflow after merge? (y/n): " WATCH_WORKFLOW
  fi

  case $workflow_step in
    "feature_to_develop")
      merge_feature_to_develop
      ;;
    "release_to_main")
      merge_release_to_main
      ;;
    *)
      echo "Invalid workflow step: $workflow_step"
      exit 1
      ;;
  esac

  watch_workflow_run
}

main
