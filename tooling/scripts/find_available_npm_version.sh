#!/bin/bash

# Script to find the next available version for npm publishing
# Usage: ./find_available_version.sh <base_version> <package_name> <registry_url>

set -e

# Function to check if version is already published
check_version_exists() {
  local version=$1
  local package_name=$2
  local registry_url=$3
  
  # Try to get version info from registry
  if npm view "$package_name@$version" version --registry="$registry_url" 2>/dev/null | grep -q "$version"; then
    return 0  # Version exists
  else
    return 1  # Version doesn't exist
  fi
}

# Function to find next available version with release number
find_available_version() {
  local base_version=$1
  local package_name=$2
  local registry_url=$3
  local release_num=1
  local test_version="${base_version}-r${release_num}"
  
  while check_version_exists "$test_version" "$package_name" "$registry_url"; do
    echo "Version $test_version already exists, trying next release number..." >&2
    release_num=$((release_num + 1))
    test_version="${base_version}-r${release_num}"
  done
  
  echo "$test_version"
}

# Main execution
main() {
  if [ $# -lt 3 ]; then
    echo "Usage: $0 <base_version> <package_name> <registry_url>"
    echo "Example: $0 '1.2.3' '@your-org/your-package' 'https://your-domain-123456789.d.codeartifact.us-east-1.amazonaws.com/npm/your-repo/'"
    exit 1
  fi
  
  local base_version=$1
  local package_name=$2
  local registry_url=$3
  
  # Check if base version exists
  if check_version_exists "$base_version" "$package_name" "$registry_url"; then
    echo "Version $base_version already exists, finding next available version with release number..." >&2
    find_available_version "$base_version" "$package_name" "$registry_url"
  else
    echo "Version $base_version is available for publishing" >&2
    echo "$base_version"
  fi
}

# If script is executed directly, run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi 