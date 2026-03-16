#!/bin/bash

# Exit on any error
set -e

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Default values
REGION="us-east-1"
DOMAIN="${CODEARTIFACT_DOMAIN:-}"
DOMAIN_OWNER="${CODEARTIFACT_DOMAIN_OWNER:-}"
REPOSITORY="${CODEARTIFACT_REPOSITORY:-}"

# Function to display usage
usage() {
    echo "Usage: $0 [-r region] [-d domain] [-o domain-owner] [-p repository]"
    echo "  -r    AWS Region (default: us-east-1)"
    echo "  -d    CodeArtifact Domain"
    echo "  -o    Domain Owner (AWS Account ID)"
    echo "  -p    Repository name"
    exit 1
}

# Parse command line options
while getopts "r:d:o:p:h" opt; do
    case $opt in
        r) REGION="$OPTARG" ;;
        d) DOMAIN="$OPTARG" ;;
        o) DOMAIN_OWNER="$OPTARG" ;;
        p) REPOSITORY="$OPTARG" ;;
        h) usage ;;
        ?) usage ;;
    esac
done

# Validate required parameters
if [ "$DOMAIN" == "" ] || [ "$DOMAIN_OWNER" == "" ] || [ "$REPOSITORY" == "" ]; then
    echo "Error: Missing required parameters"
    usage
fi

if [ -f $HOME/.npmrc ]; then
    rm $HOME/.npmrc
fi

echo "Authenticating NPM with AWS CodeArtifact..."
echo "Region: $REGION"
echo "Domain: $DOMAIN"
echo "Repository: $REPOSITORY"

# Get authentication token and configure npm
auth_token=$(aws codeartifact get-authorization-token \
    --domain "$DOMAIN" \
    --domain-owner "$DOMAIN_OWNER" \
    --query authorizationToken \
    --output text \
    --region "$REGION")

registry_url="https://$DOMAIN-$DOMAIN_OWNER.d.codeartifact.$REGION.amazonaws.com/npm/$REPOSITORY/"

# Configure npm to use CodeArtifact repository
echo "registry=$registry_url" > ~/.npmrc
echo "//$DOMAIN-$DOMAIN_OWNER.d.codeartifact.$REGION.amazonaws.com/npm/$REPOSITORY/:always-auth=true" >> ~/.npmrc
echo "//$DOMAIN-$DOMAIN_OWNER.d.codeartifact.$REGION.amazonaws.com/npm/$REPOSITORY/:_authToken=${auth_token}" >> ~/.npmrc

echo "Successfully authenticated NPM with AWS CodeArtifact!"
echo "Registry URL: $registry_url"