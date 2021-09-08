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
 * Converts a Firestore JSON response object to clean JSON object
 * @param {object} inputObject - the parsed Firestore javascript object
 * @param {resource} - the resource name of the object - so for example 'orders' or 'customers'
 * @param {keyName} - the name of the primary key of the resource - so for example 'orderId' or 'customerId'
 * @return {resultObject} - the converted resource object
 */
function convertFirestoreResponse(inputObject, resource, keyName) {
    var singleResponse = false;
    var responseObject = {};
    responseObject[resource] = [];
    if (inputObject) {
        if (!inputObject.documents) {
            singleResponse = true;
            inputObject = {
                "documents": [
                    inputObject
                ]
            };
        }
        for (var i = 0; i < inputObject.documents.length; i++) {
            var record = inputObject.documents[i];
            if (record.name) {
                var name = record.name.split('/').slice(-1)[0];
                var newRecord = {};
                newRecord[keyName] = name;
                if (record.fields) {
                    for (var key in record.fields) {
                        if (record.fields[key]) {
                            var value = record.fields[key];
                            var newValue = getValue(value);
                            if (!(newValue === undefined)) {
                            newRecord[key] = newValue;
                            }
                        }
                    }
                    responseObject[resource].push(newRecord);
                }
            }
        }
    }
    if (singleResponse) {
        responseObject = responseObject[resource][0];
    }

    return responseObject;
}

/**
 * Retrieves a Firestore value from different data type objects (String, Boolean, Geo, Timestamp)
 * @param {node} inputObject - the Firestore input object
 * @return {resultObject} - the string value of the data type
 */
function getValue(node) {
    var result;
    if (node && node.stringValue)
        result = node.stringValue;
    else if (node && node.hasOwnProperty("booleanValue"))
        result = node.booleanValue;
    else if (node && node.geoPointValue)
        result = node.geoPointValue.latitude + ", " + node.geoPointValue.longitude;
    else if (node && node.timestampValue)
        result = node.timestampValue;
    return result;
}

if (typeof exports !== 'undefined') {
    exports.convertFirestoreResponse = convertFirestoreResponse;
}
