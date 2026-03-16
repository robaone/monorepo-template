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

echo Scenario: Get the latest version on no tags

## GIVEN

export VERSIONS="
"
EXPECTED_RESULT=

## WHEN

ACTUAL_RESULT=$(eval $CMD)

## THEN

assert_equals $EXPECTED_RESULT $ACTUAL_RESULT

echo Scenario: Get the latest version from invalid tags

## GIVEN

export VERSIONS="invalid"
EXPECTED_RESULT=

## WHEN

ACTUAL_RESULT=$(eval $CMD)

## THEN

assert_equals $EXPECTED_RESULT $ACTUAL_RESULT

echo Scenario: Get the latest version from valid tags

## GIVEN

export VERSIONS="v1.0.0
v0.9.0
v0.10.0
v0.0.2500"
EXPECTED_RESULT=1.0.0

## WHEN

ACTUAL_RESULT=$(eval $CMD)

## THEN

assert_equals $EXPECTED_RESULT $ACTUAL_RESULT

echo Scenario: Get the latest version from combination of tags

## GIVEN

export VERSIONS="v1.0.0
my-change
v0.9.0
something-else-v2.0.0
v0.10.0
v0.0.2500
v1.2.0-develop.1"
EXPECTED_RESULT=1.0.0

## WHEN

ACTUAL_RESULT=$(eval $CMD)

## THEN

assert_equals $EXPECTED_RESULT $ACTUAL_RESULT