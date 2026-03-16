#!/bin/bash

tickets=$(git log origin/main..HEAD | grep -o '[A-Z][A-Z]*-[0-9][0-9]*' | sort | uniq)

if [ -z "$tickets" ]; then
  echo "No tickets found"
  exit 1
fi

echo $tickets
