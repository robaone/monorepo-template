#!/bin/bash

CMD=$1

function assert_equals {
  if [ "$1" != "$2" ]; then
    echo "Expected $1 but got $2"
    exit 1
  else
    echo "OK"
  fi
}

echo Scenario: Update major release on breaking change

# GIVEN
export CURRENT_VERSION=1.23.5
export GIT_LOGS='commit 00000000000000
Author: Me
Date: my date

     feat: This is a feature with a breaking change
     
     BREAKING CHANGE: I changed everything!
'
EXPECTED_VERSION=2.0.0

# WHEN
ACTUAL_RESULT=$(eval $CMD)

#THEN
assert_equals $EXPECTED_VERSION $ACTUAL_RESULT

echo Scenario: Update feature release on change containing feat

# GIVEN
export CURRENT_VERSION=1.23.5
export GIT_LOGS='commit 00000000000000
Author: Me
Date: my date

     feat: This is a feature with a change
'
EXPECTED_VERSION=1.24.0

# WHEN
ACTUAL_RESULT=$(eval $CMD)

#THEN
assert_equals $EXPECTED_VERSION $ACTUAL_RESULT

echo Scenario: Update patch release on change containing fix

# GIVEN
export CURRENT_VERSION=1.23.5
export GIT_LOGS='commit 00000000000000
Author: Me
Date: my date

     fix: I fixed something
'
EXPECTED_VERSION=1.23.6

# WHEN
ACTUAL_RESULT=$(eval $CMD)

#THEN
assert_equals $EXPECTED_VERSION $ACTUAL_RESULT

echo Scenario: Support squash commits

# GIVEN
export CURRENT_VERSION=1.23.5
export GIT_LOGS='commit 00000000000000
Author: Me
Date: my date

     ci: My squashed commit
    
    * feat: 🎸 BILL-213 add script for predicting next version with tests
    
    * test: 💍 BILL-213 setup unit tests
    
    * ci: 🎡 BILL-213 add dependency in workflow
    
    * fix: 🐛 BILL-213 fix broken tests

'
EXPECTED_VERSION=1.23.5

# WHEN
ACTUAL_RESULT=$(eval $CMD)

#THEN
assert_equals $EXPECTED_VERSION $ACTUAL_RESULT

echo Scenario: Predict version 1.0.0 when there is no current version

# GIVEN
export CURRENT_VERSION=""
export TESTING=true
export GIT_LOGS='commit 00000000000000
Author: Me
Date: my date

     feat: My squashed commit

'
EXPECTED_VERSION=1.0.0

# WHEN
ACTUAL_RESULT=$(eval $CMD)

#THEN
assert_equals $EXPECTED_VERSION $ACTUAL_RESULT

echo Scenario: Discern commit message types

# GIVEN
export CURRENT_VERSION=1.23.5
export GIT_LOGS='commit 00000000000000
Author: Me
Date: my date

     fix: My squashed commit
    
    * feat: 🎸 BILL-213 add script for predicting next version with tests
    
    * test: 💍 BILL-213 setup unit tests
    
    * ci: 🎡 BILL-213 add dependency in workflow
    
    * fix: 🐛 BILL-213 fix broken tests

'
EXPECTED_VERSION=1.23.6