#!/bin/sh

set -e

[ -z "$SPEC" ] && echo "Specification Missing" && exit
[ -z "$OPERATION" ] && echo "Operation Missing" && exit

# Build up AssignMessage policy
RESULT="<AssignMessage name=\"Assign."$OPERATION"Request\">"
RESULT="$RESULT""<AssignTo createNew=\"true\" type=\"request\">"$OPERATION"Request</AssignTo>"

# Set target url as a variable for use in TargetEndpoint, ServiceCallout or TargetServer
RESULT="$RESULT""<AssignVariable>"
RESULT="$RESULT""<Name>"$OPERATION".url</Name>"
RESULT="$RESULT""<Value>$(cat $SPEC | jq -r '.servers[].url')</Value>"
RESULT="$RESULT""</AssignVariable>"

# <Set>
RESULT="$RESULT""<Set>"

# Path Suffix
PATHSUFFIX=$(cat "$SPEC" | jq -r ".paths
  | select(.[][].operationId == \"$OPERATION\") 
  | .[] 
  | keys[]")

RESULT="$RESULT""<Path>"
RESULT="$RESULT""$PATHSUFFIX"
RESULT="$RESULT""</Path>"

# Set Headers
RESULT="$RESULT""<Headers>"
HEADERS=$(cat "$SPEC" | jq -r ".paths 
  | select(.[][].operationId == \"$OPERATION\") 
  | .[][].parameters[] 
  | select(.in==\"header\") 
  | .name")

for HEADER in $HEADERS; do
  RESULT="$RESULT""<Header name=\"$HEADER\">"
  RESULT="$RESULT""{custom.header."$HEADER"}"
  RESULT="$RESULT""</Header>"
done
RESULT="$RESULT""</Headers>"

# Query Params
RESULT="$RESULT""<QueryParams>"
QPS=$(cat "$SPEC" | jq -r ".paths
  | select(.[][].operationId == \"$OPERATION\")
  | .[][].parameters[]
  | select(.in==\"query\")
  | .name")

for QP in $QPS; do
  RESULT="$RESULT""<QueryParam name=\"$QP\">"
  RESULT="$RESULT""{custom.queryparams."$QP"}"
  RESULT="$RESULT""</QueryParam>"
done
RESULT="$RESULT""</QueryParams>"

# payload
RESULT="$RESULT""<Payload>"
RESULT="$RESULT""{custom.payload}"
RESULT="$RESULT""</Payload>"

RESULT="$RESULT""</Set>"
RESULT="$RESULT""</AssignMessage>"

echo $RESULT
