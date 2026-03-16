#!/bin/bash

# This script takes a list of files and returns the project names for those files

# Example:
# echo "GithubWebhook/README.md" | parse_file_list_for_projects.sh
# GithubWebhook

INPUT="$(cat)"

if [ "$INPUT" == "" ]; then
  echo "You must provide a list of files"
  exit 1
fi

if [ "$PROJECT_ROOT" == "" ]; then
  PROJECT_ROOT=.
fi

SCRIPT_DIR=$(cd $(dirname $0); pwd)

if [ "$BUILD_DEPENDS_PATH" == "" ]; then
  BUILD_DEPENDS_PATH="$SCRIPT_DIR/build_depends_project_list.sh"
fi

function folder_exists() {
  local FOLDER=$1
  if [ "$FOLDER_EXISTS_CMD" != "" ]; then
    $FOLDER_EXISTS_CMD "$FOLDER"
    return $?
  else
    if [ -d "$FOLDER" ]; then
      echo 1
    else
      echo 0
    fi
  fi
}

function git_root() {
  git rev-parse --show-toplevel
}

if [ "$(folder_exists "$(git_root)/$PROJECT_ROOT")" == "0" ]; then
  exit 0
fi

# for each line get the first folder name
if [ "$PROJECT_ROOT" == "." ]; then
  FOLDERS="$(echo "$INPUT" | sed 's/\// /g' | awk '{print $1}' | sort | uniq)"
else
  FOLDERS="$(echo "$INPUT" | grep ''$PROJECT_ROOT'[/]' | sed 's/\// /g' | awk '{print $1 "/" $2}' | sort | uniq)"
fi

# get list of folders triggered by dependencies
if [ "$PROJECT_ROOT" == "." ]; then
  DEPENDS_FOLDERS="$(echo "$INPUT" | $BUILD_DEPENDS_PATH | awk '{print $1}')"
else
  DEPENDS_FOLDERS="$(echo "$INPUT" | $BUILD_DEPENDS_PATH | awk '{print "'$PROJECT_ROOT'/" $1}')"
fi

# combine with FOLDERS and remove duplicates
FOLDERS="$(echo "$FOLDERS $DEPENDS_FOLDERS" | tr ' ' '\n' | sort -u)"

if [ "$FOLDERS_THAT_DONT_EXIST" == "" ]; then
  for FOLDER in $FOLDERS
  do
    if [ "$(folder_exists "$FOLDER")" == "0" ]; then
      FOLDERS_THAT_DONT_EXIST="$FOLDERS_THAT_DONT_EXIST $FOLDER"
    fi
  done
fi

if [ "$PROJECT_ROOT" == "." ]; then
  IGNORE_LIST="$IGNORE_LIST .github"
fi
IGNORE_LIST="$IGNORE_LIST $FOLDERS_THAT_DONT_EXIST"

function folder_is_in_list() {
  local FOLDER=$1
  local LIST="$2"
  for IGNORE in $LIST
  do
    if [ "$FOLDER" == "$IGNORE" ]; then
      echo 0
    fi
  done
  echo 1
}
NEW_FOLDERS=""

for FOLDER in $FOLDERS
do
  if [ "$(folder_is_in_list "$FOLDER" "$IGNORE_LIST")" == "1" ]; then
    NEW_FOLDERS="$NEW_FOLDERS $FOLDER"
  fi
done

# replace space with return character
if [ "$PROJECT_ROOT" == "." ]; then
  FOLDERS=$(echo $NEW_FOLDERS | sed 's/ /\n/g')
else
  FOLDERS=$(echo $NEW_FOLDERS | sed 's/ /\n/g' | sed 's/^'$PROJECT_ROOT'\///g')
fi
echo "$FOLDERS"