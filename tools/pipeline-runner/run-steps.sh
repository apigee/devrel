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


SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
PIPELINE_REPORT="run-steps,0"                                         

for CMD in $(cat "$SCRIPTPATH"/steps.json | jq '.steps[]' -r); do
  $CMD
  PIPELINE_REPORT="$PIPELINE_REPORT;$CMD,$?"                     
done

echo                                                                                                                                    
echo "STEP RESULTS"                                                                                                                     
echo "$PIPELINE_REPORT" | tr ";" "\n" | awk -F"," '$2 = ($2 > 0 ? "fail" : "pass")' OFS=";" | column -s ";" -t                          
echo                                                                                                                                    
                                                                                                                                        
# set exit code                                                                                                                         
! echo "$PIPELINE_REPORT" | tr ";" "\n" | awk -F"," '{ print $2 }' | grep -v -q "0"
