#!/bin/bash

if [ "$1" == "" ] || [ "$2" == "" ]; then
  echo "Usage: [release version] [project key]"
  exit 1
fi

function setupVariables() {
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  JIRA_CONFIG="$($SCRIPT_DIR/jira_get_config.sh)"
  TOKEN=$(echo $JIRA_CONFIG | jq -r .auth.token)
  USERNAME=$(echo $JIRA_CONFIG | jq -r .auth.user)
  COMPANY=$(echo $JIRA_CONFIG | jq -r .jira.domain)
  
  if [ "$JIRA_URL" == "" ]; then
    JIRA_URL="https://$COMPANY.atlassian.net/rest/api/3"
  fi
  
  if [ "$CURL_PATH" == "" ]; then
    CURL_PATH="$(which curl)"
  fi
  
  if [ "$DATE_PATH" == "" ]; then
    DATE_PATH="$(which date)"
  fi
  
  RELEASE_DATE=$(date +'%Y-%m-%d')
}

function get_project_by_key (){
  local url="$JIRA_URL/project/$1"
  response="$($CURL_PATH -X GET -H "Accept: application/json" -u "$USERNAME:$TOKEN" "$url" 2>/dev/null)"
  echo "$response"
}

function update_release() {
  local release="$1"
  local projectId="$2"
  local release_id="$(existing_release "$release" "$projectId" | jq -r .id)"
  local payload="$3"

  local url="$JIRA_URL/version/$release_id"

  # Use curl to get both response body and status code
  local response_body
  local http_status

  # Execute curl and capture both response body and status code
  response_file=$(mktemp)
  http_code=$($CURL_PATH -s -o "$response_file" -w "%{http_code}" \
    -X PUT \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -u "$USERNAME:$TOKEN" \
    "$url" \
    -d "$payload" 2>/dev/null)

  response_body=$(cat "$response_file")
  rm "$response_file"

  # Return or print both values as needed
  echo "Response Body: $response_body"
  echo "HTTP Status Code: $http_code"

  # Optionally, return just the status code if that's all you need:
  return $http_status
}

function get_versions() {
  local projectId="$1"
  local release="$2"
  # Use Jira's query parameters to filter by name exactly
  local url="$JIRA_URL/project/${projectId}/version?query=${release}&maxResults=1"
  response=$($CURL_PATH -X GET -H "Accept: application/json" -u "$USERNAME:$TOKEN" "$url" 2>/dev/null)
  
  # Check if the response is valid JSON
  if ! echo "$response" | jq -e . >/dev/null 2>&1; then
    echo "Error: Invalid JSON response from Jira API" >&2
    echo "$response" >&2
    exit 1
  fi
  
  # Check if we got an error response
  if echo "$response" | jq -e '.errorMessages' >/dev/null 2>&1; then
    echo "Error from Jira API:" >&2
    echo "$response" | jq -r '.errorMessages[]' >&2
    exit 1
  fi
  
  echo "$response" | jq '.values'
}

function existing_release() {
  local release="$1"
  local projectId="$2"
  local versions="$(get_versions $projectId $release)"
  local existing_release="$(echo "$versions" | jq -r '.[] | select(.name == "'$release'")')"
  echo "$existing_release"
}

function check_ticket_statuses() {
  local release="$1"
  local projectId="$2"
  
  # URL encode the JQL query
  local jql="fixVersion='$release' AND project='$projectId' AND status NOT IN ('Waiting for Release', 'Done')"
  local encoded_jql=$(echo "$jql" | jq -sRr @uri)
  
  # Get all tickets in the release that are not in Waiting for Release or Done status
  local url="$JIRA_URL/search?jql=$encoded_jql&fields=key,status"
  response=$($CURL_PATH -X GET -H "Accept: application/json" -u "$USERNAME:$TOKEN" "$url" 2>/dev/null)
  
  # Check for API errors
  if ! echo "$response" | jq -e . >/dev/null 2>&1; then
    echo "Error: Invalid JSON response from Jira API" >&2
    echo "$response" >&2
    exit 1
  fi
  
  if echo "$response" | jq -e '.errorMessages' >/dev/null 2>&1; then
    echo "Error from Jira API:" >&2
    echo "$response" | jq -r '.errorMessages[]' >&2
    exit 1
  fi
  
  # Get the count of tickets in invalid states
  local invalid_tickets=$(echo "$response" | jq '.issues | length')
  
  if [ $invalid_tickets -gt 0 ]; then
    echo "The following tickets are not in 'Waiting for Release' or 'Done' status:" >&2
    echo "$response" | jq -r '.issues[] | "\(.key): \(.fields.status.name)"' >&2
    echo "Release will not be marked as released" >&2
    return 1
  fi
  
  return 0
}

function get_all_unreleased_versions() {
  local releaseName="$1"
  local projectId="$2"
  local repoName=$(echo $releaseName | sed 's/-v[0-9].*$//')
  local url="$JIRA_URL/project/${projectId}/version?maxResults=100&status=unreleased"
  response=$($CURL_PATH -X GET -H "Accept: application/json" -u "$USERNAME:$TOKEN" "$url" 2>/dev/null)
  echo "$response" | jq --arg repoName "${repoName}-v" --arg version "${releaseName}" '[.values[] | select(.name | startswith($repoName)) | select(.name != $version) | {name: .name, id: .id} ]'
}

function find_release_date() {
  local releaseName="$1"
  local versionNumber=$(echo $releaseName | sed -n 's/.*-\(v[0-9].*\)$/\1/p')
  git show "$versionNumber" --format='%ad' --date=short --no-patch
}

function main() {
  setupVariables
  # Main execution
  PROJECT_ID="$(get_project_by_key "$2" | jq -r .id)"
  
  echo "Checking ticket statuses for release '$1'..."
  if check_ticket_statuses "$1" "$PROJECT_ID"; then
    echo "All tickets are in appropriate states, marking release as released..."
    payload=$(jq --null-input \
      --arg released "true" \
      --arg releaseDate "$RELEASE_DATE" \
      '{
        released: $released,
        releaseDate: $releaseDate
      }')
    update_release "$1" "$PROJECT_ID" "$payload"
  else
    echo "Updating release date only..."
    payload=$(jq --null-input \
      --arg releaseDate "$RELEASE_DATE" \
      '{
        releaseDate: $releaseDate
      }')
    update_release "$1" "$PROJECT_ID" "$payload"
  fi
  
  echo "Retroactively releasing unreleased versions..."
  UNRELEASED_VERSIONS="$(get_all_unreleased_versions "$1" "$PROJECT_ID")"
  if [ "$(echo "$UNRELEASED_VERSIONS" | jq '. | length')" -eq 0 ]; then
    echo "No unreleased versions found."
    return
  else
    echo "Found unreleased versions:"
    echo "$UNRELEASED_VERSIONS" | jq -r '.[]'
  fi
  
  echo "$UNRELEASED_VERSIONS" | jq -c '.[]' | while read -r version; do
    versionId=$(echo "$version" | jq -r '.id')
    versionName=$(echo "$version" | jq -r '.name')
  
    echo "Checking version: $versionName (ID: $versionId)"
  
    if check_ticket_statuses "$versionName" "$PROJECT_ID"; then
      DISCOVERED_RELEASE_DATE="$(find_release_date "$versionName")"
      payload=$(jq --null-input \
      --arg released "true" \
      --arg releaseDate "$DISCOVERED_RELEASE_DATE" \
      '{
        released: $released,
        releaseDate: $releaseDate
      }')
      update_release "$versionName" "$PROJECT_ID" "$payload"
    else
      echo "Still can't be released"
    fi
  done
}

main "$1" "$2"
