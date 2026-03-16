#!/bin/bash

# filepath: /Users/anselrobateau/git/rsm-monorepo/create_symlinks.sh

# Define the source files
CURSOR_RULES_SOURCE="../../.cursorrules"
WINDSURF_RULES_SOURCE="../../.windsurfrules"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Define the base directory containing all domain directories
DOMAINS_DIR="$SCRIPT_DIR/../../domains"

# Iterate over all directories in the domains folder
for domain in "$DOMAINS_DIR"/*; do
  cd $domain
    if [ -d "$domain" ]; then
      if [ -f ".cursorrules" ]; then
        rm .cursorrules
      fi
      if [ ! -f ".cursorrules" ]; then
        echo "Creating symlink for .cursorrules in $domain"
        # Create symlinks for .cursorrules
        ln -sf "$CURSOR_RULES_SOURCE" ".cursorrules"
        echo "Symlinked .cursorrules to $domain"
      fi
      if [ -f ".windsurfrules" ]; then
        rm .windsurfrules
      fi
      if [ ! -f ".windsurfrules" ]; then
        echo "Creating symlink for .windsurfrules in $domain"

        # Create symlinks for .windsurfrules
        ln -sf "$WINDSURF_RULES_SOURCE" ".windsurfrules"
        echo "Symlinked .windsurfrules to $domain"
      fi
    fi
  cd ..
done

echo "Symlinks created for all domains."