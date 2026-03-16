#!/bin/bash

PROMPT="$1"

if [ -z "$PROMPT" ]; then
  echo "Error: PROMPT is not set"
  exit 1
fi

OWL_THEME="An owl with red rimmed glasses in "
STYLE="in the style of a cartoon"
SCRIPT_DIR=$(dirname "$0")

$SCRIPT_DIR/ai_image_generator.sh "$OWL_THEME $PROMPT $STYLE"