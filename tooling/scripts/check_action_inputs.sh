#!/bin/bash

# Check if file path is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-action.yml>"
    exit 1
fi

action_file="$1"

# Check if file exists
if [ ! -f "$action_file" ]; then
    echo "Error: File '$action_file' does not exist"
    exit 1
fi

echo "Analyzing $action_file"
echo "----------------------"

# Find the line number where inputs section starts
inputs_start=$(grep -n "^inputs:" "$action_file" | cut -d: -f1)

if [ -z "$inputs_start" ]; then
    echo "No inputs section found in the file"
    exit 0
fi

# Extract all input variables between inputs: and runs: sections
inputs=$(sed -n "/^inputs:/,/^runs:/p" "$action_file" | grep "^  [a-zA-Z0-9_-]*:$" | sed 's/^  //' | sed 's/:$//')

# Initialize counter for unused inputs
unused_count=0

# Check each input variable
for input in $inputs; do
    # Count occurrences of the input variable in ${{ inputs.xxx }} format, allowing for spaces
    # Also handle the case where there might not be a space after inputs.
    count=$(grep -c "\${{[[:space:]]*inputs\.$input[[:space:]]*}}\|\${{[[:space:]]*inputs\.$input}}" "$action_file")
    
    # If count is 0, report it
    if [ "$count" -eq 0 ]; then
        if [ $unused_count -eq 0 ]; then
            echo "Found unused input variables:"
            echo
        fi
        ((unused_count++))
        description=$(sed -n "/^  $input:/,/^  [a-zA-Z0-9_-]*:/p" "$action_file" | grep "description:" | sed 's/^    description: //' | sed 's/"//g')
        required=$(sed -n "/^  $input:/,/^  [a-zA-Z0-9_-]*:/p" "$action_file" | grep "required:" | sed 's/^    required: //')
        echo "$unused_count. Input variable: $input"
        echo "   Description: $description"
        echo "   Required: $required"
        echo
    fi
done

if [ $unused_count -eq 0 ]; then
    echo "No unused input variables found"
fi 