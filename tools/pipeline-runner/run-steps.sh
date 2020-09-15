#!/bin/sh
for CMD in $(cat steps.json | jq '.steps[]' -r); do
  $CMD
done
