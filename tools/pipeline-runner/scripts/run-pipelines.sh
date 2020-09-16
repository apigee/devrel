#!/bin/sh
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

echo "DevRel - Project Pipeline Check"

DIR="${1:-$PWD}"
PIPELINE_REPORT="project-pipelines,0"

if [ -z "$APIGEE_USER" ] && [ -z "$APIGEE_PASS" ]; then
  echo "NO CREDENTIALS - SKIPPING PIPELINES"
elif test -f "$DIR/pipeline.sh"; then
  PATH=$PATH:./tools/another-apigee-client ./tools/organization-cleanup/organization-cleanup.sh
  (cd "$DIR" && ./pipeline.sh;)
  PIPELINE_REPORT="$PIPELINE_REPORT;$DIR Pipeline,$?"
else
  for TYPE in references labs tools; do
    for D in $DIR/$TYPE/*; do
      PATH=$PATH:./tools/another-apigee-client ./tools/organization-cleanup/organization-cleanup.sh
      (cd $D && ./pipeline.sh;)
      PIPELINE_REPORT="$PIPELINE_REPORT;$D Pipeline,$?"
    done
  done
fi

# print report
echo
echo "PROJECT PIPELINES"
echo "$PIPELINE_REPORT" | tr ";" "\n" | awk -F"," '$2 = ($2 > 0 ? "fail" : "pass")' OFS=";" | column -s ";" -t
echo

# set exit code
! echo "$PIPELINE_REPORT" | tr ";" "\n" | awk -F"," '{ print $2 }' | grep -v -q "0"

