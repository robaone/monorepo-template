#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

npx jest $SCRIPT_DIR/generate_release_notes.test.js