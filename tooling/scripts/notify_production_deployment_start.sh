#!/bin/bash

set -e

function setup_environment_variables() {
  if [ "$CURL_CMD" == "" ]; then
    CURL_CMD="curl"
  fi
  if [ "$JQ_CMD" == "" ]; then
    JQ_CMD="jq"
  fi
  if [ "$GIT_CMD" == "" ]; then
    GIT_CMD="git"
  fi
}

function validate_env_vars() {
  if [ "$SLACK_WEBHOOK_URL" == "" ]; then
    echo "SLACK_WEBHOOK_URL is required"
    exit 1
  fi
  if [ "$GITHUB_WORKFLOW_RUN_URL" == "" ]; then
    echo "GITHUB_WORKFLOW_RUN_URL is required"
    exit 1
  fi
}

function notify_slack() {
  local message="$1"
  local webhook_url="$2"
  $CURL_CMD -X POST -H 'Content-type: application/json' --data "{\"text\":\"$message\"}" $webhook_url
}

function notify_slack_deployment_message() {
  local repo="$1"
  local version="$2"
  local workflow_run_url="$3"
  local message="⚙️ *Deploying ${repo}-v${version} to production*\n• workflow: ${workflow_run_url}\n• Jira tickets: https://${JIRA_DOMAIN:-your-jira-domain.atlassian.net}/issues/?jql=fixVersion%20%3D%20${repo}-v${version}"
  echo "$message"
}

function main() {
  validate_env_vars
  setup_environment_variables
  local repo="$(basename $($GIT_CMD rev-parse --show-toplevel))"
  local version="$($JQ_CMD -r '.version' package.json)"
  local workflow_run_url="$GITHUB_WORKFLOW_RUN_URL"
  local webhook_url="$SLACK_WEBHOOK_URL"
  local message=$(notify_slack_deployment_message "$repo" "$version" "$workflow_run_url")
  notify_slack "$message" "$webhook_url"
}

main
