#!/bin/bash

if [ "$1" == "" ]; then
  echo "Usage: [template-file.yml]"
  exit 1
else
  TEMPLATE_FILE=$1
fi

if [ "$OPENAI_API_KEY" == "" ]; then
  echo "Please set the OPENAI_API_KEY environment variable"
  exit 1
fi

if [ "$CURL_CMD" == "" ]; then
  CURL_CMD="curl"
fi

if [ "$OPENAI_MODEL" == "" ]; then
  OPENAI_MODEL="o1-preview"
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: File '$TEMPLATE_FILE' not found"
  exit 1
fi

TEMPLATE_CONTENT="$(cat "$TEMPLATE_FILE")"

function create_the_prompt() {
  # The prompt below includes the user instructions plus the template content.
  # You can customize the wording to your liking.
  read -r -d '' USER_PROMPT << EOM
Please analyze the following AWS Serverless CloudFormation template and produce
an expanded Mermaid data flow diagram that:
1. Enumerates all SNS topics and all SQS queues from the template.
2. Consolidates all Lambda functions into a single node labeled “All Lambdas.”
3. Demonstrates the key data flows:
    - SNS Topics → SQS Queues → Lambdas
    - Lambdas → SQS Queues
    - Lambdas → SNS Topics
    - Lambdas → Database (via RDS Proxy)
Put the SNS topics together in a subgraph, the SQS queues in another subgraph,
show arrows for the message flows, and label nodes clearly for readability.
Here is the template.yml content:
\`\`\`yaml
$TEMPLATE_CONTENT
\`\`\`
When you respond, please:
1. Provide a Mermaid diagram code only.
Thank you!
EOM
}

function build_request_payload() {
  REQUEST_PAYLOAD=$(jq -n \
    --arg role_user "user" \
    --arg content_user "$USER_PROMPT" \
    '[
      {
        "role": $role_user,
        "content": $content_user
      }
    ]'
  )
}

function send_request() {
  RESPONSE=$(
    $CURL_CMD -s "https://api.openai.com/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -d "$(jq -n \
        --arg model "$OPENAI_MODEL" \
        --argjson messages "$REQUEST_PAYLOAD" \
        '{model: $model, messages: $messages}')"
  )
  if [ "$?" != "0" ]; then
    echo "$RESPONSE"
    exit 1
  fi
  echo "$RESPONSE"
}

function main() {
  create_the_prompt
  build_request_payload
  send_request
}

main