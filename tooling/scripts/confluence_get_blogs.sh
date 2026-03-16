#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$CURL_CMD" == "" ]; then
    CURL_CMD="curl"
fi

JIRA_CONFIG="$($SCRIPT_DIR/jira_get_config.sh)"
ATLASSIAN_USER=$(echo $JIRA_CONFIG | jq -r .auth.user)
ATLASSIAN_API_TOKEN=$(echo $JIRA_CONFIG | jq -r .auth.token)
DOMAIN="$(echo $JIRA_CONFIG | jq -r .jira.domain)"

function url_encode() {
    local raw="$1"
    local encoded=""
    local length="${#raw}"
    for (( i = 0; i < length; i++ )); do
        local c="${raw:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) encoded+="$c" ;;
            *) encoded+=$(printf '%%%02X' "'$c") ;;
        esac
    done
    echo "$encoded"
}

function get_blog_by_title() {
    BLOG_TITLE="$1"
    RESPONSE=$($CURL_CMD --silent --request GET \
    --url "https://$DOMAIN.atlassian.net/wiki/api/v2/blogposts?title=$(url_encode "$BLOG_TITLE")&body-format=storage" \
    --user "$ATLASSIAN_USER:$ATLASSIAN_API_TOKEN" \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json')

    echo $RESPONSE
}

function main() {
    if [ "$1" == "" ]; then
        echo "Usage: <option> [blog_title]"
        echo ""
        echo "  -t, --title <title> The blog post title"
        exit 1
    fi

    OPTION=$1
    BLOG_TITLE=$2

    if [ "$OPTION" == "-t" ] || [ "$OPTION" == "--title" ]; then
        get_blog_by_title "$BLOG_TITLE"
    else
        echo "Invalid option: $OPTION"
        exit 1
    fi
}

main "$@" 