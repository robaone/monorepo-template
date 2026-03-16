#!/bin/bash

# Configuration
REPO="${GITHUB_REPOSITORY:-YOUR_ORG/YOUR_REPO}"  # Set via GITHUB_REPOSITORY env var or replace with your repository name
BRANCH="develop"
FAILURE_TRACK_FILE="previous_failures.txt"

# Fetch failed workflow runs in JSON format
NEW_FAILURES=$(gh run list --repo "$REPO" --branch "$BRANCH" --status failure --json databaseId,url)

# Ensure the tracking file exists
touch "$FAILURE_TRACK_FILE"

# Read previously stored failure IDs
PREVIOUS_FAILURES=$(cat "$FAILURE_TRACK_FILE")

# Initialize JSON output
JSON_OUTPUT="["

# Process the failures
NEWLY_DETECTED=()
while IFS= read -r line; do
    ID=$(echo "$line" | jq -r '.databaseId')
    URL=$(echo "$line" | jq -r '.url')
    
    if ! grep -q "$ID" "$FAILURE_TRACK_FILE"; then
        NEWLY_DETECTED+=("{\"id\":\"$ID\",\"url\":\"$URL\"}")
        echo "$ID" >> "$FAILURE_TRACK_FILE"
    fi
done <<< "$(echo "$NEW_FAILURES" | jq -c '.[]')"

# Construct JSON output
if [ ${#NEWLY_DETECTED[@]} -ne 0 ]; then
    JSON_OUTPUT+=$(IFS=,; echo "${NEWLY_DETECTED[*]}")
fi
JSON_OUTPUT+="]"

# Print pure JSON result
echo "$JSON_OUTPUT"
