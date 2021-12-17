#! /bin/bash
# shellcheck disable=SC2206
# Copyright 2021 Google LLC
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

echo
echo Using Apigee X project \""$PROJECT_ID"\" and dataset bqml

bq --project_id="$PROJECT_ID" --location=us mk --dataset "$PROJECT_ID":bqml
bq --project_id="$PROJECT_ID" mk --table "$PROJECT_ID":bqml.prod_recommendations userId:STRING,itemId:STRING,predicted_session_duration_confidence:FLOAT
bq --project_id="$PROJECT_ID" load --autodetect --replace --source_format=NEWLINE_DELIMITED_JSON "$PROJECT_ID":bqml.prod_recommendations ./prod_recommendations_json.txt
bq --project_id="$PROJECT_ID" query --nouse_legacy_sql \
    "SELECT * FROM \`$PROJECT_ID.bqml.prod_recommendations\` AS A" \
    ORDER BY A.userId ASC, predicted_session_duration_confidence DESC
