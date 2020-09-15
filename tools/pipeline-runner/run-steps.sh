#!/bin/sh

set -e 

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

for CMD in $(cat $SCRIPTPATH/steps.json | jq '.steps[]' -r); do
  $CMD
done
