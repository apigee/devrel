/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

var responseBody = {};

try {
    responseBody = JSON.parse(context.getVariable("response.content"));
} catch (e) {
    context.setVariable("bq.response.error", "JSON parse failed");
}

const bqFields = responseBody.schema.fields;

const fields = [];

for (var i = 0; i < bqFields.length; i++) {
   fields.push(bqFields[i].name);
}

const bqRows = responseBody.rows;

results = []
for (var row = 0; row < bqRows.length; row++) {
    result = {};
    bqCols = bqRows[row].f;
    for (var col = 0; col < bqCols.length; col++) {
        result[fields[col]]=bqCols[col].v;
    }
    results.push(result);
}

context.setVariable("response.content", JSON.stringify(results));