#!/bin/bash

CMD=$1

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function assert() {
  if [ "$1" != "$2" ]; then
    echo "Expected: $1"
    echo "Actual:   $2"
    exit 1
  else
    echo "OK"
  fi
}

function beforeAll() {
  export GIT_CMD=$SCRIPT_DIR/mock_cmd.sh
  export MERGE_FEATURE_TO_DEVELOP_CMD=$SCRIPT_DIR/mock_cmd.sh
  export MERGE_RELEASE_TO_DEVELOP_CMD=$SCRIPT_DIR/mock_cmd.sh
  export MERGE_RELEASE_TO_MAIN_CMD=$SCRIPT_DIR/mock_cmd.sh
  export WATCH_WORKFLOW_CMD=$SCRIPT_DIR/mock_cmd.sh
  export GH_CMD=$SCRIPT_DIR/mock_cmd.sh
  export GIT_FLOW_BRANCH_CMD=$SCRIPT_DIR/mock_cmd.sh
  export EXPECT_CMD=$SCRIPT_DIR/mock_cmd.sh
  export SILENT=true
}

function beforeEach() {
  export MOCK_ARGUMENT_FILE=$(mktemp)
  export MOCK_TRACKING_FILE=$(mktemp)
  export WATCH_WORKFLOW=n
}

beforeAll



echo Scenario: Block merge when there are untracked files
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"name":"git_flow_branch develop","stdout":"develop"},
{"name":"git_flow_branch main","stdout":"main"},
{"name":"get branch name","stdout":"feature"},
{"name":"status --porcelain","stdout":"?? new-file.txt"}
]'

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert "1" "$?"
assert "===========================================
Branch Analysis Report
===========================================
Current branch: feature
Workflow step: feature_to_develop
-------------------------------------------
Local Changes:
Untracked files:
  ?? new-file.txt
-------------------------------------------
WARNING: You have uncommitted changes in your working directory.
Please either:
  1. Commit your changes:
     git add <files>
     git commit -m \"your message\"
  2. Stash your changes:
     git stash
  3. Discard your changes:
     git reset --hard
-------------------------------------------" "${ACTUAL_RESULT}"

echo Scenario: Block merge when there are modified files
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"name":"git_flow_branch develop","stdout":"develop"},
{"name":"git_flow_branch main","stdout":"main"},
{"name":"get branch name","stdout":"feature"},
{"name":"status --porcelain","stdout":" M modified-file.txt"},
{"name":"status --porcelain","stdout":" M modified-file.txt"},
{"name":"status --porcelain","stdout":" M modified-file.txt"},
{"name":"status --porcelain","stdout":" M modified-file.txt"}
]'

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert "1" "$?"
assert "===========================================
Branch Analysis Report
===========================================
Current branch: feature
Workflow step: feature_to_develop
-------------------------------------------
Local Changes:
Modified files:
  M modified-file.txt
-------------------------------------------
WARNING: You have uncommitted changes in your working directory.
Please either:
  1. Commit your changes:
     git add <files>
     git commit -m \"your message\"
  2. Stash your changes:
     git stash
  3. Discard your changes:
     git reset --hard
-------------------------------------------" "${ACTUAL_RESULT}"

echo Scenario: Block merge when there are deleted files
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"name":"git_flow_branch develop","stdout":"develop"},
{"name":"git_flow_branch main","stdout":"main"},
{"name":"get branch name","stdout":"feature"},
{"name":"status --porcelain","stdout":" D deleted-file.txt"},
{"name":"status --porcelain","stdout":" D deleted-file.txt"},
{"name":"status --porcelain","stdout":" D deleted-file.txt"},
{"name":"status --porcelain","stdout":" D deleted-file.txt"}
]'

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert "1" "$?"
assert "===========================================
Branch Analysis Report
===========================================
Current branch: feature
Workflow step: feature_to_develop
-------------------------------------------
Local Changes:
Deleted files:
  D deleted-file.txt
-------------------------------------------
WARNING: You have uncommitted changes in your working directory.
Please either:
  1. Commit your changes:
     git add <files>
     git commit -m \"your message\"
  2. Stash your changes:
     git stash
  3. Discard your changes:
     git reset --hard
-------------------------------------------" "${ACTUAL_RESULT}"

echo Scenario: Block merge when there are staged changes
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"name":"git_flow_branch develop","stdout":"develop"},
{"name":"git_flow_branch main","stdout":"main"},
{"name":"get branch name","stdout":"feature"},
{"name":"status --porcelain","stdout":"A staged-file.txt"},
{"name":"status --porcelain","stdout":"A staged-file.txt"},
{"name":"status --porcelain","stdout":"A staged-file.txt"},
{"name":"status --porcelain","stdout":"A staged-file.txt"}
]'

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert "1" "$?"
assert "===========================================
Branch Analysis Report
===========================================
Current branch: feature
Workflow step: feature_to_develop
-------------------------------------------
Local Changes:
Staged changes:
  A staged-file.txt
-------------------------------------------
WARNING: You have uncommitted changes in your working directory.
Please either:
  1. Commit your changes:
     git add <files>
     git commit -m \"your message\"
  2. Stash your changes:
     git stash
  3. Discard your changes:
     git reset --hard
-------------------------------------------" "${ACTUAL_RESULT}"

echo Scenario: Allow merge when there are no local changes and PR is ready
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"name":"git_flow_branch develop","stdout":"develop"},
{"name":"git_flow_branch main","stdout":"main"},
{"name":"get branch name","stdout":"feature"},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"pr list --json number,baseRefName,headRefName,mergeable,mergeStateStatus,reviewDecision,url --state open","stdout":"[{\"number\":123,\"baseRefName\":\"develop\",\"headRefName\":\"feature\",\"mergeable\":true,\"mergeStateStatus\":\"CLEAN\",\"reviewDecision\":\"APPROVED\",\"url\":\"https://github.com/org/repo/pull/123\"}]"},
{"name":"merge-base","stdout":"abc123"},
{"name":"log --oneline abc123..feature","stdout":"def456 feat: add new feature"},
{"name":"feature to develop merge","stdout":"Merged feature to develop"}
]'

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert "0" "$?"
assert "===========================================
Branch Analysis Report
===========================================
Current branch: feature
Workflow step: feature_to_develop
-------------------------------------------
Local Changes:
  - No uncommitted changes
Feature Branch Status:
  - PR URL: https://github.com/org/repo/pull/123
  - Status: READY
  Unmerged Changes:
    - Unmerged commits to develop:
      def456 feat: add new feature
-------------------------------------------
Available Actions:
1. Merge feature to develop
2. Watch workflow after merge (optional)
===========================================
Executing feature to develop merge...
Merged feature to develop" "${ACTUAL_RESULT}"

echo Scenario: Block merge when there is no open PR to develop
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"name":"git_flow_branch develop","stdout":"develop"},
{"name":"git_flow_branch main","stdout":"main"},
{"name":"get branch name","stdout":"feature"},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"pr list --json number,baseRefName,headRefName,mergeable,mergeStateStatus,reviewDecision,url --state open","stdout":"[]"},
{"name":"merge-base","stdout":"abc123"},
{"name":"log --oneline abc123..feature","stdout":"def456 feat: add new feature"}
]'

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert "1" "$?"
assert "===========================================
Branch Analysis Report
===========================================
Current branch: feature
Workflow step: feature_to_develop
-------------------------------------------
Local Changes:
  - No uncommitted changes
Feature Branch Status:
  - No open PR to develop
  Unmerged Changes:
    - Unmerged commits to develop:
      def456 feat: add new feature
-------------------------------------------
Available Actions:
No merges available - PR not ready" "${ACTUAL_RESULT}"

echo Scenario: Block merge when PR has conflicts
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"name":"git_flow_branch develop","stdout":"develop"},
{"name":"git_flow_branch main","stdout":"main"},
{"name":"get branch name","stdout":"feature"},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"pr list --json number,baseRefName,headRefName,mergeable,mergeStateStatus,reviewDecision,url --state open","stdout":"[{\"number\":123,\"baseRefName\":\"develop\",\"headRefName\":\"feature\",\"mergeable\":false,\"mergeStateStatus\":\"DIRTY\",\"reviewDecision\":\"APPROVED\",\"url\":\"https://github.com/org/repo/pull/123\"}]"},
{"name":"merge-base","stdout":"abc123"},
{"name":"log --oneline abc123..feature","stdout":"def456 feat: add new feature"}
]'

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert "1" "$?"
assert "===========================================
Branch Analysis Report
===========================================
Current branch: feature
Workflow step: feature_to_develop
-------------------------------------------
Local Changes:
  - No uncommitted changes
Feature Branch Status:
  - PR URL: https://github.com/org/repo/pull/123
  - Status: CONFLICTS
  Unmerged Changes:
    - Unmerged commits to develop:
      def456 feat: add new feature
-------------------------------------------
Available Actions:
No merges available - PR not ready" "${ACTUAL_RESULT}"

echo Scenario: Block merge when PR is pending review
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"name":"git_flow_branch develop","stdout":"develop"},
{"name":"git_flow_branch main","stdout":"main"},
{"name":"get branch name","stdout":"feature"},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"pr list --json number,baseRefName,headRefName,mergeable,mergeStateStatus,reviewDecision,url --state open","stdout":"[{\"number\":123,\"baseRefName\":\"develop\",\"headRefName\":\"feature\",\"mergeable\":true,\"mergeStateStatus\":\"CLEAN\",\"reviewDecision\":\"PENDING_REVIEW\",\"url\":\"https://github.com/org/repo/pull/123\"}]"},
{"name":"merge-base","stdout":"abc123"},
{"name":"log --oneline abc123..feature","stdout":"def456 feat: add new feature"}
]'

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert "1" "$?"
assert "===========================================
Branch Analysis Report
===========================================
Current branch: feature
Workflow step: feature_to_develop
-------------------------------------------
Local Changes:
  - No uncommitted changes
Feature Branch Status:
  - PR URL: https://github.com/org/repo/pull/123
  - Status: PENDING_REVIEW
  Unmerged Changes:
    - Unmerged commits to develop:
      def456 feat: add new feature
-------------------------------------------
Available Actions:
No merges available - PR not ready" "${ACTUAL_RESULT}"

echo Scenario: Block merge when PR has changes requested
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"name":"git_flow_branch develop","stdout":"develop"},
{"name":"git_flow_branch main","stdout":"main"},
{"name":"get branch name","stdout":"feature"},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"pr list --json number,baseRefName,headRefName,mergeable,mergeStateStatus,reviewDecision,url --state open","stdout":"[{\"number\":123,\"baseRefName\":\"develop\",\"headRefName\":\"feature\",\"mergeable\":true,\"mergeStateStatus\":\"CLEAN\",\"reviewDecision\":\"CHANGES_REQUESTED\",\"url\":\"https://github.com/org/repo/pull/123\"}]"},
{"name":"merge-base","stdout":"abc123"},
{"name":"log --oneline abc123..feature","stdout":"def456 feat: add new feature"}
]'

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert "1" "$?"
assert "===========================================
Branch Analysis Report
===========================================
Current branch: feature
Workflow step: feature_to_develop
-------------------------------------------
Local Changes:
  - No uncommitted changes
Feature Branch Status:
  - PR URL: https://github.com/org/repo/pull/123
  - Status: CHANGES_NEEDED
  Unmerged Changes:
    - Unmerged commits to develop:
      def456 feat: add new feature
-------------------------------------------
Available Actions:
No merges available - PR not ready" "${ACTUAL_RESULT}"

echo Scenario: Block merge when on develop branch
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"name":"git_flow_branch develop","stdout":"develop"},
{"name":"git_flow_branch main","stdout":"main"},
{"name":"get branch name","stdout":"develop"},
{"name":"status --porcelain","stdout":""}
]'

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert "1" "$?"
assert "You cannot merge develop" "${ACTUAL_RESULT}"

echo Scenario: Block merge when on main branch
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"name":"git_flow_branch develop","stdout":"develop"},
{"name":"git_flow_branch main","stdout":"main"},
{"name":"get branch name","stdout":"main"},
{"name":"status --porcelain","stdout":""}
]'

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert "1" "$?"
assert "You cannot merge main" "${ACTUAL_RESULT}"

echo Scenario: Block merge when on release branch
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"name":"git_flow_branch develop","stdout":"develop"},
{"name":"git_flow_branch main","stdout":"main"},
{"name":"get branch name","stdout":"release/v1.0.0"},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"pr list --json number,baseRefName,headRefName,mergeable,mergeStateStatus,reviewDecision,url --state open","stdout":"[{\"number\":123,\"baseRefName\":\"main\",\"headRefName\":\"release/v1.0.0\",\"mergeable\":false,\"mergeStateStatus\":\"DIRTY\",\"reviewDecision\":\"APPROVED\",\"url\":\"https://github.com/org/repo/pull/123\"}]"},
{"name":"merge-base","stdout":"abc123"},
{"name":"log --oneline abc123..release/v1.0.0","stdout":"def456 feat: release v1.0.0"}
]'

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert "1" "$?"
assert "===========================================
Branch Analysis Report
===========================================
Current branch: release/v1.0.0
Workflow step: release_to_main
-------------------------------------------
Local Changes:
  - No uncommitted changes
Release/Hotfix Branch Status:
  PR to main:
    - PR URL: https://github.com/org/repo/pull/123
    - Status: CONFLICTS
  Note: After successful production deployment, a workflow will automatically
        create a PR from main to develop and merge it if there are no conflicts.
  Unmerged Changes:
    - Unmerged commits to main:
      def456 feat: release v1.0.0
-------------------------------------------
Available Actions:
No merges available - PR not ready" "${ACTUAL_RESULT}"

echo Scenario: Block merge when on hotfix branch
beforeEach

# GIVEN
export MOCK_RESPONSES='[
{"name":"git_flow_branch develop","stdout":"develop"},
{"name":"git_flow_branch main","stdout":"main"},
{"name":"get branch name","stdout":"hotfix/v1.0.1"},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"status --porcelain","stdout":""},
{"name":"pr list --json number,baseRefName,headRefName,mergeable,mergeStateStatus,reviewDecision,url --state open","stdout":"[{\"number\":123,\"baseRefName\":\"main\",\"headRefName\":\"hotfix/v1.0.1\",\"mergeable\":false,\"mergeStateStatus\":\"DIRTY\",\"reviewDecision\":\"APPROVED\",\"url\":\"https://github.com/org/repo/pull/123\"}]"},
{"name":"merge-base","stdout":"abc123"},
{"name":"log --oneline abc123..hotfix/v1.0.1","stdout":"def456 fix: critical bug fix"}
]'

# WHEN
ACTUAL_RESULT="$($CMD)"

# THEN
assert "1" "$?"
assert "===========================================
Branch Analysis Report
===========================================
Current branch: hotfix/v1.0.1
Workflow step: release_to_main
-------------------------------------------
Local Changes:
  - No uncommitted changes
Release/Hotfix Branch Status:
  PR to main:
    - PR URL: https://github.com/org/repo/pull/123
    - Status: CONFLICTS
  Note: After successful production deployment, a workflow will automatically
        create a PR from main to develop and merge it if there are no conflicts.
  Unmerged Changes:
    - Unmerged commits to main:
      def456 fix: critical bug fix
-------------------------------------------
Available Actions:
No merges available - PR not ready" "${ACTUAL_RESULT}"
