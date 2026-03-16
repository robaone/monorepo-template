#!/bin/bash

# this script checks for the existence of the gh cli

if ! command -v gh &> /dev/null
then
    echo "gh could not be found"
    echo "See: https://github.com/cli/cli#installation"
    exit 1
fi
