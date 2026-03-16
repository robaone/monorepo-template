#!/bin/bash

# Create a new project folder
# Insert a package.json file that has default values

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PARENT_FOLDER=domains

if [ "$MKDIR_CMD" == "" ]; then
  MKDIR_CMD="mkdir"
fi

if [ "$CP_CMD" == "" ]; then
  CP_CMD="cp"
fi

if [ "$JQ_CMD" == "" ]; then
  JQ_CMD="jq"
fi

# Check if the project name is provided
if [ -z "$1" ]; then
  echo "Please provide a project name"
  exit 1
fi

# Check if project name is all lower case and skewer case
if [[ ! "$1" =~ ^[a-z]+(-[a-z]+)*$ ]]; then
  echo "Project name must be all lower case and skewer case"
  exit 1
fi

# Check if the project folder already exists
if [ -d "$SCRIPT_DIR/../../${PARENT_FOLDER}/$1" ]; then
  echo "Project folder already exists"
  exit 1
fi

# Create the project folder
$MKDIR_CMD "$SCRIPT_DIR/../../${PARENT_FOLDER}/$1"

# Copy the package.json file
$CP_CMD "$SCRIPT_DIR/../templates/package.json" "$SCRIPT_DIR/../../${PARENT_FOLDER}/$1/package.json"

# Replace the project name in the package.json file using jq
NEW_PACKAGE_JSON=$($JQ_CMD --arg name "$1" '.name = $name' "$SCRIPT_DIR/../../${PARENT_FOLDER}/$1/package.json")
if [ "$TEST" == "true" ]; then
  exit 0
fi
echo "$NEW_PACKAGE_JSON" > "$SCRIPT_DIR/../../${PARENT_FOLDER}/$1/package.json.tmp" && mv "$SCRIPT_DIR/../../${PARENT_FOLDER}/$1/package.json.tmp" "$SCRIPT_DIR/../../${PARENT_FOLDER}/$1/package.json"

