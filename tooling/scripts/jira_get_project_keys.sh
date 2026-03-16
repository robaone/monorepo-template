#!/bin/bash

if [ "$1" == "" ] ; then 
  echo "Usage: [filename]"
  exit 1
fi

jq -r '.issues[] | .key' "$1" | sed s/-[0-9]*$// | sort | uniq | tr '\n' ' '
