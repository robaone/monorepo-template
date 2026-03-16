#!/bin/bash

# Configure the ~/.tooling/config.json and ~/.jira-cli/config.json file

# Ask for the Jira domain
echo "Please enter your Jira domain (e.g. mycompany):"
read JIRA_DOMAIN

if [ -z "$JIRA_DOMAIN" ]; then
  echo "Jira domain cannot be empty."
  exit 1
fi

# Ask for the user's email address
echo "Please enter your email address:"
read EMAIL

# Make sure it is a valid email address
if [[ $EMAIL != *@* ]]; then
  echo "Invalid email address. Please enter a valid email address."
  exit 1
fi

# Ask for Jira API token
echo "Please enter your Jira API token:"
echo "You can generate a Jira API token at https://id.atlassian.com/manage-profile/security/api-tokens"
read JIRA_API_TOKEN

# Make sure the Jira API token is not empty
if [ -z "$JIRA_API_TOKEN" ]; then
  echo "Jira API token cannot be empty. Please enter a valid Jira API token."
  exit 1
fi

# Ask for the preferred feature branch prefix
echo "Please enter your preferred feature branch prefix (optional):"
echo "This is the prefix that will be used when creating a new feature branch."
echo "For example, if you enter 'feature/', the branch name will be 'feature/COMPANY-1234-feature-name'."
read FEATURE_PREFIX

# Tooling configuration
mkdir -p ~/.tooling

function create_tooling_file {
  cat > ~/.tooling/config.json <<EOF
{
  "feature": {
    "prefix": "$FEATURE_PREFIX"
  },
  "profile": {
    "email": "$EMAIL"
  },
  "jira": {
    "domain": "$JIRA_DOMAIN"
  },
  "images": {
    "default_gif": ""
  },
  "workflow": {
    "skippable": {
      "cd": false,
      "e2e": false
    }
  }
}
EOF
}

# Check to see if the file already exists and ask if the user wants to overwrite it
if [ -f ~/.tooling/config.json ]; then
  echo "~/.tooling/config.json already exists. Do you want to overwrite it? (y/n)"
  read OVERWRITE
  if [ "$OVERWRITE" == "y" ]; then
    cp ~/.tooling/config.json ~/.tooling/config.json.bak
    create_tooling_file
  fi
else
  create_tooling_file
fi

# Jira CLI configuration
mkdir -p ~/.jira-cli

function create_jira_file {
  cat > ~/.jira-cli/config.json <<EOF
{
  "auth": {
    "user": "$EMAIL",
    "token": "$JIRA_API_TOKEN"
  },
  "jira": {
    "domain": "$JIRA_DOMAIN"
  }
}
EOF
}

# Check to see if the file already exists and ask if the user wants to overwrite it
if [ -f ~/.jira-cli/config.json ]; then
  echo "~/.jira-cli/config.json already exists. Do you want to overwrite it? (y/n)"
  read OVERWRITE
  if [ "$OVERWRITE" == "y" ]; then
    cp ~/.jira-cli/config.json ~/.jira-cli/config.json.bak
    create_jira_file
  fi
else
  create_jira_file
fi