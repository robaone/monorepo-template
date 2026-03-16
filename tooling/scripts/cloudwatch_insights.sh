#!/bin/bash

# CloudWatch Insights Query Tool - JavaScript Wrapper
# This script is now a wrapper for the JavaScript implementation
# The JavaScript version provides better error handling, modularity, and JSON output

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JS_SCRIPT="$SCRIPT_DIR/cloudwatch_insights.js"

# Check if the JavaScript version exists
if [ ! -f "$JS_SCRIPT" ]; then
    echo "Error: JavaScript version not found at $JS_SCRIPT" >&2
    echo "Please ensure cloudwatch_insights.js is in the same directory as this script." >&2
    exit 1
fi

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is required but not installed or not in PATH" >&2
    echo "Please install Node.js to use this script." >&2
    exit 1
fi

# Pass all arguments to the JavaScript version
exec node "$JS_SCRIPT" "$@"
