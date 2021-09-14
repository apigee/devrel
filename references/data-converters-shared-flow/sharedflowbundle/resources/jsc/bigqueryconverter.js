/**
 * Copyright 2021 Google LLC
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

/**
 * Converts BigQuery JSON response format to clean JSON object
 * @param {object} inputObject - the parsed BigQuery Javascript object
 * @param {string} resource - the resource name of the object - so for example 'orders' or 'customers'
 * @return {object} resultObject - the converted resource object
 */
function convertBigQueryResponse(inputObject, resource) {
    var result = {};
    result[resource] = [];
    
    for (var rowKey in inputObject.rows) {
        if (inputObject.rows[rowKey]) {
            var row = inputObject.rows[rowKey];
            var newRow = {};
            for (var valueKey in row.f) {
                if (row.f[valueKey]) {
                    var value = row.f[valueKey];
                    newRow[inputObject.schema.fields[valueKey].name] = value.v;
                }
            }
            result[resource].push(newRow);
        }
    }
    
    return result;
}

if (typeof exports !== 'undefined') {
    exports.convertBigQueryResponse = convertBigQueryResponse;
}
