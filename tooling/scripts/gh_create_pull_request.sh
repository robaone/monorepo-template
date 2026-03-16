#!/bin/bash

# This bash script creates a new pull request on GitHub with a formatted body based on a Jira ticket. It first sets some variables based on the input parameters and the current working directory, and then runs a shell script to check for some conditions. If these conditions are not met, the script exits with an error.

# The script then prompts the user for a pull request title if one is not provided, and sets a variable to indicate whether to skip continuous deployment (CD) or not. It then extracts the Jira ticket ID from the current Git branch, and prompts the user to provide a URL for a GIF to include in the pull request body, or automatically sets a default one if none is provided.

# The script then creates a temporary file to store the pull request body, which includes the GIF URL, the Jira ticket description, a link to the ticket, a checkbox to indicate whether to skip CD, and some other fields. It then creates a new label in the GitHub repository if it does not exist, and creates a new pull request with the specified title and body, and assigns the label to the pull request.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PR_TITLE="$1"
GIF_URL="$2"
PARTIAL_IMPLEMENTATION=${3:-false}

$SCRIPT_DIR/gh_check.sh
if [ "$?" != "0" ]; then
  exit 1
fi

if [ "$TOOLING_CONFIG_FILE" == "" ]; then
  TOOLING_CONFIG_FILE=~/.tooling/config.json
fi

# get config from ~/.tooling/config.json file if it exists
if [ -f "$TOOLING_CONFIG_FILE" ]; then
  JIRA_DOMAIN=$(jq -r '.jira.domain' "$TOOLING_CONFIG_FILE")
  SKIPPABLE_CD=$(jq -r '.workflow.skippable.cd' "$TOOLING_CONFIG_FILE")
  SKIPPABLE_E2E=$(jq -r '.workflow.skippable.e2e' "$TOOLING_CONFIG_FILE")
fi
if [ "$JIRA_DOMAIN" == "" ]; then
  read -p "Enter Jira domain: " JIRA_DOMAIN
fi

if [ "$GIT_FLOW_BRANCH_CMD" == "" ]; then
  GIT_FLOW_BRANCH_CMD=$SCRIPT_DIR/git_flow_branch.sh
fi

if [ "$GIT_CMD" == "" ]; then
  GIT_CMD=git
fi

if [ "$GH_CMD" == "" ]; then
  GH_CMD=gh
fi

if [ "$PR_TITLE" == "" ]; then
  # prompt for pull request title
  read -p "Pull request title: " PR_TITLE
  while [ -z "$PR_TITLE" ]; do
    read -p "Title cannot be empty. Please enter a pull request title: " PR_TITLE
  done
fi

if [ "$DEPLOY" == "true" ]; then
  SKIP_CD=" "
  SKIP_E2E=" "
else
  SKIP_CD="x"
  SKIP_E2E="x"
fi

function extract_ticket_id {
  local message=$1
  local trello_pattern="TRELLO-[a-zA-Z0-9][a-zA-Z0-9]*"
  local jira_pattern="[A-Z][A-Z]*-[0-9][0-9]*"
  if [[ $message =~ $trello_pattern ]]; then
    echo $message | grep -o "$trello_pattern"
  elif [[ $message =~ $jira_pattern ]]; then
    echo $message | grep -o "$jira_pattern"
  else
    echo ""
  fi
}

function get_git_url() {
  if [ "$PROVIDE_GIF_URL" == "n" ]; then
    GIF_URL=""
  fi
  if [ "$GIF_URL" == "" ] || [ "$GIF_URL" == "Ticket has no parent" ]; then
    echo "No gif url found"
    echo $GIF_URL
    exit 1
  fi
}

function build_ticket_url() {
  local ticket_id=$1
  local trello_pattern="TRELLO-[a-zA-Z0-9][a-zA-Z0-9]*"
  local jira_pattern="[A-Z][A-Z]*-[0-9][0-9]*"
  local github_issue="ISSUE-[0-9][0-9]*"
  if [[ $ticket_id =~ $trello_pattern ]]; then
    echo "https://trello.com/c/$(echo $ticket_id | sed 's/TRELLO-//')"
    TICKET_SOURCE="trello"
  elif [[ $ticket_id =~ $github_issue ]]; then
    echo "https://github.com/${GITHUB_REPOSITORY_OWNER:-YOUR_ORG}/$(basename $(git rev-parse --show-toplevel))/issues/$(echo $ticket_id | sed 's/ISSUE-//')"
    TICKET_SOURCE
  elif [[ $ticket_id =~ $jira_pattern ]]; then
    echo "https://${JIRA_DOMAIN}.atlassian.net/browse/$ticket_id"
    TICKET_SOURCE="jira"
  else
    echo ""
  fi
}

TICKET_ID=$(extract_ticket_id "$($GIT_CMD branch --show-current)")

if [ "$TICKET_ID" == "" ]; then
  echo "No ticket found"
  # prompt to continue without a ticket
  read -p "Do you want to continue without a ticket? (y/n): " CONTINUE
  if [ "$CONTINUE" == "y" ]; then
    TICKET_ID="NO-TICKET"
  else
    exit 1
  fi
fi

## Get current working directory
CURRENT_DIR=$(dirname $BASH_SOURCE)
if [ "$GIF_URL" == "" ]; then
  # prompt asking if the user wants to provide a gif url
  read -p "Do you want to provide a gif url? (y/n): " PROVIDE_GIF_URL
  if [ "$PROVIDE_GIF_URL" == "y" ]; then
    # prompt for gif url
    read -p "Gif url: " GIF_URL
  else
    get_git_url
  fi
  if [ "$?" != "0" ]; then
    exit 1
  fi
fi
TICKET_URL=$(build_ticket_url $TICKET_ID)

# prompt for a description
if [ "$DESCRIPTION" == "" ]; then
  read -p "Enter a description: " DESCRIPTION
fi

if [ "$TEMP_FILE" == "" ]; then
  TEMP_FILE=$(mktemp)
fi

echo "<img width=\"250\" src=\"$GIF_URL\" />" > $TEMP_FILE
echo "" >> $TEMP_FILE
echo "### Description:" >> $TEMP_FILE
echo "" >> $TEMP_FILE
echo "$DESCRIPTION" >> $TEMP_FILE
echo "" >> $TEMP_FILE
if [ "$TICKET_ID" != "NO-TICKET" ]; then
  echo "### Ticket:" >> $TEMP_FILE
  echo "" >> $TEMP_FILE
  echo "$TICKET_URL" >> $TEMP_FILE
  echo "" >> $TEMP_FILE
fi
if [ "$SKIPPABLE_CD" == "true" ]; then
  echo "- [$SKIP_CD] Skip CD" >> $TEMP_FILE
fi
if [ "$SKIPPABLE_E2E" == "true" ]; then
  echo "- [$SKIP_E2E] Skip e2e" >> $TEMP_FILE
fi
if [ "$PARTIAL_IMPLEMENTATION" == "true" ]; then
  echo "- [x] Partial Implementation" >> $TEMP_FILE
fi
echo "" >> $TEMP_FILE
echo "### Changes: (complexity: ?)" >> $TEMP_FILE
echo "" >> $TEMP_FILE
echo "- [ ] Change 1" >> $TEMP_FILE
echo "" >> $TEMP_FILE
echo "### Validation:" >> $TEMP_FILE
echo "" >> $TEMP_FILE
echo "- [ ] Validation 1" >> $TEMP_FILE

GH_QA_LABEL="pending-qa"
PARTIAL_IMPLEMENTATION_LABEL="partial-implementation"

target_branch=$($GIT_FLOW_BRANCH_CMD develop)

if [ "$($GH_CMD label list | grep $GH_QA_LABEL)" == "" ]; then
  $GH_CMD label create $GH_QA_LABEL
fi

if [ "$PARTIAL_IMPLEMENTATION" == "true" ]; then
  if [ "$($GH_CMD label list | grep $PARTIAL_IMPLEMENTATION_LABEL)" == "" ]; then
    $GH_CMD label create $PARTIAL_IMPLEMENTATION_LABEL --color "FFA500" --description "This PR is a partial implementation"
  fi
  # create in draft mode
  $GH_CMD pr create --base $target_branch --title "$PR_TITLE ($TICKET_ID) [skip-release-notes]" --body-file $TEMP_FILE --label pending-qa --label "$PARTIAL_IMPLEMENTATION_LABEL" --draft
else
  $GH_CMD pr create --base $target_branch --title "$PR_TITLE ($TICKET_ID)" --body-file $TEMP_FILE --label pending-qa --draft
fi


