#!/bin/bash

# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

DIRS="$1"
PIPELINE_REPORT=""
DEVREL_ROOT="$PWD"

PATH=$PATH:"$DEVREL_ROOT/tools/another-apigee-client"
PATH=$PATH:"$DEVREL_ROOT/tools/apigee-sackmesser/bin"

append_pipeline_result() {
  echo "$1" | awk 'NF' | awk -F"," '$2 = ($2 > 0 ? "fail" : "pass")' OFS=";" >> pipeline-result.txt
}

run_single_pipeline() {
  DIR=$1
  STARTTIME=$(date +%s)
  (cd "$DIR" && ./pipeline.sh > >(sed "s#^#$(date "+%H:%M:%S") $DIR: #") 2> >(sed "s#^#$(date "+%H:%M:%S") $DIR (err): #" >&2))
  PIPELINE_EXIT=$?
  ENDTIME=$(date +%s)
  append_pipeline_result "$DIR,$PIPELINE_EXIT,$((ENDTIME-STARTTIME))s"
  echo "[INFO] DevRel Pipeline done: $DIR"
}

if [ -z "$APIGEE_USER" ] && [ -z "$APIGEE_PASS" ]; then
  echo "[WARN] NO CREDENTIALS - SKIPPING PIPELINES"
  exit 0
fi

if [ -z "$DIRS" ]; then
  for TYPE in references labs tools; do
    for D in "$DEVREL_ROOT"/"$TYPE"/*; do
      DIRS="$DIRS,$D"
    done
  done
  DIRS=$(echo "$DIRS" | cut -c 2-)
fi

# Allowing some solutions to run independently and async
# because they don't have any side effects on the Apigee orgs
# used for CI/CD.
declare -A async_projects=(
 [./tools/hybrid-quickstart]=1  [./tools/apigee-x-trial-provision]=1
)
async_pipeline_pids=''

STARTTIME=$(date +%s)

# Starting async builds
for DIR in ${DIRS//,/ }
do
  RELATIVE_DIR=".${DIR:${#DEVREL_ROOT}}"
  if [ -n "${async_projects[$RELATIVE_DIR]}" ] && [ -f  "$DIR/pipeline.sh" ]; then
    run_single_pipeline "$DIR" &
    pid=$!
    async_pipeline_pids="$async_pipeline_pids $pid"
    echo "[INFO] DevRel Pipeline: $DIR (async) #$pid"
  fi
done

for DIR in ${DIRS//,/ }
do
  RELATIVE_DIR=".${DIR:${#DEVREL_ROOT}}"
  if ! test -f  "$DIR/pipeline.sh"; then
    echo "[WARN] $DIR/pipeline.sh NOT FOUND"
    append_pipeline_result "[N/A] $DIR,0,0s"
  elif [ -n "${async_projects[$RELATIVE_DIR]}" ]; then
    echo "[INFO] DevRel Pipeline: $DIR (async, already started)"
  else
    echo "[INFO] DevRel Pipeline: $DIR"
    run_single_pipeline "$DIR"
  fi
done

echo "[INFO] Awaiting Async Pipelines"
for pid in $(echo "$async_pipeline_pids" | tr ";" "\n"); do
  echo "[INFO] Awaiting #$pid"
  wait "$pid"
  echo "[INFO] Done #$pid (return=$?)"
done

ENDTIME=$(date +%s)
append_pipeline_result "TOTAL PIPELINE,0,$((ENDTIME-STARTTIME))s"

# print report
echo
echo "FINAL RESULT"
column -s ";" -t ./pipeline-result.txt
echo

# set exit code
! echo "$PIPELINE_REPORT" | tr ";" "\n" | awk -F"," '{ print $2 }' | grep -v -q "0"

