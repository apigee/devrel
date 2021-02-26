#!/bin/sh

# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "Licens
# you may not use this file except in compliance with the Lic
# You may obtain a copy of the License at
#
# <http://www.apache.org/licenses/LICENSE-2.0>
#
# Unless required by applicable law or agreed to in writing,
# distributed under the License is distributed on an "AS IS"
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either expres
# See the License for the specific language governing permiss
# limitations under the License.

# shellcheck disable=2140

set -e

[ -z "$SPEC" ] && echo "Specification Missing" && exit
[ -z "$OPERATION" ] && echo "Operation Missing" && exit

# Build up AssignMessage policy
RESULT="<AssignMessage name=\"Assign.$OPERATION\">"
RESULT="$RESULT<AssignTo createNew=\"true\" type=\"request\">$OPERATION</AssignTo>"

# Set target url as a variable for use in TargetEndpoint, ServiceCallout or TargetServer
RESULT="$RESULT<AssignVariable>"
RESULT="$RESULT<Name>custom.url</Name>"
RESULT="$RESULT<Value>$(jq -r '.servers[].url' < "$SPEC")</Value>"
RESULT="$RESULT</AssignVariable>"

# <Set>
RESULT="$RESULT<Set>"

# <Verb>
VERB=$(jq -r ".paths
  | select(.[][].operationId == \"$OPERATION\")
  | .[]
  | keys[]" < "$SPEC")

RESULT="$RESULT<Verb>"
RESULT="$RESULT$VERB"
RESULT="$RESULT</Verb>"

# Path Suffix
PATHSUFFIX=$(jq -r ".paths
  | select(.[][].operationId == \"$OPERATION\") 
  | keys[]" < "$SPEC")

RESULT="$RESULT<Path>"
RESULT="$RESULT$PATHSUFFIX"
RESULT="$RESULT</Path>"

# Set Headers
RESULT="$RESULT<Headers>"
HEADERS=$(jq -r ".paths 
  | select(.[][].operationId == \"$OPERATION\") 
  | .[][].parameters[] 
  | select(.in==\"header\") 
  | .name" < "$SPEC")

for HEADER in $HEADERS; do
  RESULT="$RESULT<Header name=\"$HEADER\">"
  RESULT="$RESULT{custom.header.$HEADER}"
  RESULT="$RESULT</Header>"
done
RESULT="$RESULT""</Headers>"

# Query Params
RESULT="$RESULT""<QueryParams>"
QPS=$(jq -r ".paths
  | select(.[][].operationId == \"$OPERATION\")
  | .[][].parameters[]
  | select(.in==\"query\")
  | .name" < "$SPEC")

for QP in $QPS; do
  RESULT="$RESULT<QueryParam name=\"$QP\">"
  RESULT="$RESULT{custom.queryparams.$QP}"
  RESULT="$RESULT</QueryParam>"
done
RESULT="$RESULT</QueryParams>"

# payload
RESULT="$RESULT<Payload>"
RESULT="$RESULT{custom.payload}"
RESULT="$RESULT</Payload>"

RESULT="$RESULT</Set>"
RESULT="$RESULT</AssignMessage>"

echo "$RESULT"
