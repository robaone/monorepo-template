#!/bin/bash

# Define the API endpoint and your API key
API_KEY="$LLM_API_TOKEN"
API_ENDPOINT="https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-8b:generateContent?key=$API_KEY"

# Define the prompt
if [ "$LLM_PROMPT" == "" ]; then
  LLM_PROMPT="Create a fun release description in 100 characters or less without identifiers:
"
fi
INPUT="$1"

if [ "$CURL_CMD" == "" ]; then
  CURL_CMD="$(which curl)"
fi

compose_payload() {
  local prompt="$1"
  local input="$2"
  local base_payload='{"contents":[{"parts":[{"text":""}]}]}';
  # use jq to insert the prompt and input into the base payload
  echo $base_payload | jq --arg prompt "$prompt" --arg input "$input" '.contents[0].parts[0].text = $prompt + $input'
}

# Send the request to the Gemini API
response=$($CURL_CMD -s -X POST $API_ENDPOINT \
  -H "Content-Type: application/json" \
  -d "$(compose_payload "$LLM_PROMPT" "$INPUT")")

# Extract and output the result content
result=$(echo $response | jq -r '.candidates[0].content.parts[0].text')
echo "$result"
