#!/bin/bash

REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
WORKFLOW_NAME=$(git branch --show-current)  # Use current branch name as workflow name
POLL_INTERVAL=5

# Get the ID of the latest run for the workflow
get_latest_run_id() {
  local branch_name=$(git branch --show-current)
  # gh run list -R robaone/source --limit 5 --json createdAt,displayTitle,event,headBranch,headSha,name,number,startedAt,status,updatedAt,workflowName,databaseId | jq '.[] | select(.headBranch == "feature/watch-workflows")'
  local run_list="$(gh run list -R "$REPO" --limit 5 --json createdAt,displayTitle,event,headBranch,headSha,name,number,startedAt,status,updatedAt,workflowName,databaseId | jq '.[] | select(.headBranch == "'${branch_name}'")' | jq --slurp)"
  if [ -z "$run_list" ]; then
    return
  fi
  echo "$run_list" | jq -r 'sort_by(.createdAt) | reverse | .[0].databaseId'
}

view_run_details() {
    # gh run view 11390165109 -R robaone/source
    gh run view "$1" -R "$2"
}

# Get the status of the workflow run
get_run_status() {
  local run_id=$1
  gh run view "$run_id" -R "$REPO" --json status,conclusion --jq '{status: .status, conclusion: .conclusion}'
}

latest_run_id=$(get_latest_run_id)

if [ -z "$latest_run_id" ]; then
  echo "No workflow runs found for $WORKFLOW_NAME"
  exit 1
fi

echo "Monitoring workflow run ID: $latest_run_id"

while true; do
  run_status=$(get_run_status "$latest_run_id")
  status=$(echo "$run_status" | jq -r '.status')
  conclusion=$(echo "$run_status" | jq -r '.conclusion')

  if [ "$status" == "completed" ]; then
    if [ "$conclusion" == "success" ]; then
      echo "Workflow completed successfully."
      exit 0
    else
      echo "Workflow failed with conclusion: $conclusion"
      exit 1
    fi
  else
    echo "Workflow is still running... (status: $status)"
  fi
  clear
  view_run_details "$latest_run_id" "$REPO"
  sleep "$POLL_INTERVAL"
done
