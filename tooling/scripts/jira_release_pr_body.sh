#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

function get_the_tickets() {
  # $SCRIPT_DIR/ticket_status.sh . origin/main | jq -r .url | sort | uniq | awk '{print "- [ ] " $1}'
  if [ "$REPOSITORY" == "" ]; then
    REPOSITORY=$(basename $(git rev-parse --show-toplevel))
  fi
  VERSION=$(jq -r '.version' package.json)
  echo "- https://${JIRA_DOMAIN:-your-jira-domain.atlassian.net}/issues/?jql=fixVersion%20%3D%20${REPOSITORY}-v${VERSION}"
}

function get_random_url() {
  # list of gif urls
  local gif_urls="$(cat $SCRIPT_DIR/config/release_gifs.csv)"

  # Select a random gif url
  local random_line_number=$(($RANDOM % $(echo "$gif_urls" | wc -l) + 1))
  echo "$gif_urls" | sed -n "${random_line_number}p"
}
function build_pr_body() {
  echo "<img width=\"250px\" src=\"$1\" />"
  echo ""
  echo "-Tickets:"
  echo ""
  echo "$2"
  echo ""
  echo "### Remember to Merge.  ❗️DO NOT SQUASH ❗️"
}

build_pr_body "$(get_random_url)" "$(get_the_tickets)"
