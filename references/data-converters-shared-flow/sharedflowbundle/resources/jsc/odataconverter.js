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

function convertODataResponse(inputObject, resource) {

    var newBody = {};
    
    if (inputObject.d) {
        if (inputObject.d.results && !newBody[resource])
            newBody[resource] = [];
                
        if (inputObject.d.results) {
            for (i=0; i<inputObject.d.results.length; i++) {
                var record = inputObject.d.results[i];
                
                newBody[resource].push(convertObject(record));
            }
        }
        else {
            newBody = convertObject(inputObject.d);
        }
    }

    return newBody;
}

function convertObject(inputObj) {
    var result = {};
    
    for (var prop in inputObj) {

        var myVar = inputObj[prop];

        if ((typeof myVar === 'string' || myVar instanceof String) && myVar !== "")
            result[prop] = inputObj[prop];        
    }
    
    return result;
}

if (typeof exports !== 'undefined') {
    exports.convertODataResponse = convertODataResponse;
}
