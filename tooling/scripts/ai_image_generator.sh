#!/bin/bash

# Replace with your OpenAI API key
if [ -z "$OPENAI_API_KEY" ]; then
  echo "Error: OPENAI_API_KEY is not set"
  exit 1
fi
API_KEY="$OPENAI_API_KEY"

# Prompt for the image
PROMPT="$1"

if [ -z "$PROMPT" ]; then
  echo "Error: PROMPT is not set"
  exit 1
fi

# API endpoint
ENDPOINT="https://api.openai.com/v1/images/generations"

# Make the API request
response=$(curl -s -X POST $ENDPOINT \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "dall-e-2",
    "prompt": "'"$PROMPT"'",
    "n": 1,
    "size": "1024x1024",
    "quality": "standard"
  }')

# Extract the image URL from the response
image_url=$(echo $response | jq -r '.data[0].url')

# Download the image
if [ "$OUTPUT_PATH" == "" ]; then
  OUTPUT_PATH="generated_image.png"
fi

curl -o $OUTPUT_PATH $image_url

echo "Image saved as $OUTPUT_PATH"
