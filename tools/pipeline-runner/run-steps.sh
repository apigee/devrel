#!/bin/sh

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
PIPELINE_REPORT="run-steps,0"                                         

for CMD in $(cat $SCRIPTPATH/steps.json | jq '.steps[]' -r); do
  $CMD
  PIPELINE_REPORT="$PIPELINE_REPORT;$CMD,$?"                     
done
