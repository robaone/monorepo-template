#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
JIRA_CONFIG="$($SCRIPT_DIR/jira_get_config.sh)"

TOKEN=$(echo $JIRA_CONFIG | jq -r .auth.token)
USERNAME=$(echo $JIRA_CONFIG | jq -r .auth.user)
JIRA_DOMAIN=$(echo $JIRA_CONFIG | jq -r .jira.domain)

if [ "$GIT_CMD" == "" ]; then
  GIT_CMD="$(which git)"
fi

if [ "$CURL_CMD" == "" ]; then
  CURL_CMD="$(which curl)"
fi

if [ "$JIRA_DOMAIN" == "" ] || [ "$JIRA_DOMAIN" == "null" ]; then
  echo "Please set the jira domain in the config file"
  exit
fi
CURRENT_BRANCH=$1
if [ "$CURRENT_BRANCH" == "" ]; then
  echo "Usage: [current_branch] [(optional) target_branch]"
  exit 1
fi
TARGET_BRANCH=main
if [ "$2" != "" ]; then
  TARGET_BRANCH=$2
fi

HASHES=$($GIT_CMD log $TARGET_BRANCH..$CURRENT_BRANCH --pretty=format:'%H')

if [ ! -d ~/temp ]; then
  mkdir ~/temp
fi

while IFS= read -r hash; do
  LOG=$($GIT_CMD show $hash | sed '/^diff/,$d')
  TICKET_IDS=$(echo $LOG | grep -o '[A-Z][A-Z]*-[0-9][0-9]*' | sort | uniq)
  if [ "$TICKET_IDS" != "" ]; then
    echo $TICKET_IDS > ~/temp/$hash.txt
  fi
done <<< "$HASHES"

function getTicketInfo() {
  ticketId=$1
  if [[ "$ticketId" =~ ^ISSUE-[0-9]+$ ]]; then
    echo -n "\"url\":\"https://github.com/${GITHUB_REPOSITORY_OWNER:-YOUR_ORG}/${GITHUB_REPOSITORY_NAME:-YOUR_REPO}/issues/$(echo $ticketId | sed 's/ISSUE-//')\""
  else
    TICKET_INFO=$($CURL_CMD \
      -X GET \
      --user ${USERNAME}:${TOKEN} \
      -H "Content-Type: application/json" \
      "https://${JIRA_DOMAIN}.atlassian.net/rest/api/2/issue/$ticketId" 2>/dev/null)
     echo -n "\"url\":\"https://${JIRA_DOMAIN}.atlassian.net/browse/$ticketId\",\"status\":\"$(echo $TICKET_INFO | jq -r .fields.status.name)\""
  fi
}

function hasSkipReleaseNotes() {
  commitHash=$1
  LOG=$($GIT_CMD show $commitHash | sed '/^diff/,$d')
  if [[ "$LOG" =~ \[skip-release-notes\] ]]; then
    echo -n ",\"skip-release-notes\":true"
  fi
}

while IFS= read -r hash; do
  FILE=~/temp/$hash.txt
  if [ -f "$FILE" ]; then
    while IFS= read -r ticketId; do
      if [ "$ticketId" != "" ]; then
        echo -n "{\"hash\":\"$hash\","
        getTicketInfo $ticketId
        hasSkipReleaseNotes $hash
        echo "}"
      fi
    done <<< "$(cat $FILE | sed 's/ /\n/g')"
  fi
done <<< "$HASHES"
exit 0
# Cleanup
while IFS= read -r hash; do
  FILE=~/temp/$hash.txt
  if [ -f "$FILE" ] && [ "$FILE" != "" ]; then
    rm ~/temp/$hash.txt
  fi
done <<< "$HASHES"
