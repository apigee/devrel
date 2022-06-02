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

cat | jq -Rsn --arg RUN_TYPE "$_RUN_TYPE" --arg BUILD_ID "$BUILD_ID" '
    [inputs
    | . / "\n"
    | (.[] | select(length > 0) | . / ";") as $input
    | {"build": $BUILD_ID, "type": $RUN_TYPE, "solution": $input[0], "success": $input[1] | test("pass"), "duration": $input[2]}
    ]
    | map(.duration = (.duration | sub("s"; "") | tonumber? // 0))
' > results.json

cat results.json | jq -r -c '.[]|.' | while read -r log; do
    if [ "$(echo "$log" | jq '.success')" = "true" ]; then
        SEVERITY=INFO
    else
        SEVERITY=ERROR
    fi
    gcloud logging write pipeline-results "$log" --payload-type=json --severity $SEVERITY
done