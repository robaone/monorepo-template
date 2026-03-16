#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
JIRA_CONFIG="$($SCRIPT_DIR/jira_get_config.sh)"

TOKEN=$(echo $JIRA_CONFIG | jq -r .auth.token)
USERNAME=$(echo $JIRA_CONFIG | jq -r .auth.user)
JIRA_DOMAIN=$(echo $JIRA_CONFIG | jq -r .jira.domain)

if [ "$CURL_CMD" == "" ]; then
  CURL_CMD="$(which curl)"
fi

if [ "$JIRA_DOMAIN" == "" ] || [ "$JIRA_DOMAIN" == "null" ]; then
  echo "Please set the jira domain in the config file"
  exit
fi

if [ "$1" == "" ]; then
  echo "Usage: [url] [output_file] (options)"
  echo " options:"
  echo "    --verbose -v: show verbose curl output"
  echo "    --follow-redirects -L: follow redirects"
  echo "    --json -j: request JSON format"
  echo "    --html -h: request HTML format (default)"
  exit 1
fi

URL=$1
OUTPUT_FILE=${2:-"page-content.html"}

# Parse options
VERBOSE=""
FOLLOW_REDIRECTS=""
ACCEPT_HEADER="Accept: text/html"

for arg in "$@"; do
  case $arg in
    --verbose|-v)
      VERBOSE="-v"
      shift
      ;;
    --follow-redirects|-L)
      FOLLOW_REDIRECTS="-L"
      shift
      ;;
    --json|-j)
      ACCEPT_HEADER="Accept: application/json"
      shift
      ;;
    --html|-h)
      ACCEPT_HEADER="Accept: text/html"
      shift
      ;;
  esac
done

echo "Downloading content from: $URL"
echo "Output file: $OUTPUT_FILE"

PAGE_CONTENT=$($CURL_CMD \
  -X GET \
  $VERBOSE \
  $FOLLOW_REDIRECTS \
  --user ${USERNAME}:${TOKEN} \
  -H "Content-Type: application/json" \
  -H "$ACCEPT_HEADER" \
  "$URL" 2>/dev/null)

if [ $? -eq 0 ]; then
  echo "$PAGE_CONTENT" > "$OUTPUT_FILE"
  echo "Content successfully downloaded to: $OUTPUT_FILE"
else
  echo "Error downloading content from URL: $URL"
  exit 1
fi 