/**
 * Copyright 2020 Google LLC
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

function convertFsRequest(inputObject, topCollectionKeyName, collectionKeyName) {
    var firestoreObject = {
        "fields": {}
    };
    var result = {};
    if (inputObject) {
        for (var key in inputObject) {
            var value = inputObject[key];
            var parts = [];
            if (typeof value == "string")
                parts = value.split(", ");
            if (key == topCollectionKeyName)
                result["documentKey"] = value; 
            else if (key == collectionKeyName)
                result["subDocumentKey"] = value;
            if (value && parts.length > 1 && !isNaN(parts[0])) {
                // Is a location
                firestoreObject["fields"][key] = {
                    "geoPointValue": {
                        "latitude": parts[0],
                        "longitude": parts[1]
                    }
                };
            }
            else if (value && value.toString().length > 8 && !isNaN(Date.parse(value))) {
                var dateobj = new Date(value);
                firestoreObject["fields"][key] = {
                    "timestampValue": dateobj.toISOString()
                };
            }
            else if (value && (value.toString().toLowerCase() === "true" || value.toString().toLowerCase() === "false")) {
                firestoreObject["fields"][key] = {
                    "booleanValue": (value.toString().toLowerCase() == "true")
                };
            }
            else {
                firestoreObject["fields"][key] = {
                    "stringValue": value
                };
            }
        }
    }
    result.firestoreObject = firestoreObject;
    return result;
}
function convertFsResponse(firestoreResponse, tableName, keyName) {
    var singleResponse = false;
    var responseObject = {};
    responseObject[tableName] = [];
    if (firestoreResponse) {
        if (!firestoreResponse.documents) {
            singleResponse = true;
            firestoreResponse = {
                "documents": [
                    firestoreResponse
                ]
            };
        }
        for (var i = 0; i < firestoreResponse.documents.length; i++) {
            var record = firestoreResponse.documents[i];
            if (record.name) {
                var name = record.name.split('/').slice(-1)[0];
                var newRecord = {};
                newRecord[keyName] = name;
                if (record.fields) {
                    for (var key in record.fields) {
                        var value = record.fields[key];
                        var newValue = getValue(value);
                        if (!(newValue === undefined)) {
                          newRecord[key] = newValue;
                        }
                    }
                    responseObject[tableName].push(newRecord);
                }
            }
        }
    }
    if (singleResponse) {
        responseObject = responseObject[tableName][0];
    }
    return responseObject;
}
function convertFsNestedResponse(firestoreResponse, tableName, tableKey, tableKeyValue, topcollectionName, topcollectionKeyName) {
    var singleResponse = false;
    var responseObject = {};
    responseObject[tableName] = [];
    if (firestoreResponse) {
        if (!firestoreResponse.documents) {
            singleResponse = true;
            firestoreResponse = {
                "documents": [
                    firestoreResponse
                ]
            };
        }
        else if (tableKeyValue) {
            singleResponse = true;
        }
        for (var i = 0; i < firestoreResponse.documents.length; i++) {
            var record = firestoreResponse.documents[i];
            if (record.name) {
                var name = record.name.split('/').slice(-1)[0];
                var newRecordCollection = [];

                if (record.fields) {
                    processFields(record.fields, topcollectionName, tableName, tableKey, tableKeyValue, newRecordCollection);
                    for (var l = 0; l < newRecordCollection.length; l++) {
                        newRecordCollection[l][topcollectionKeyName] = name;
                    }
                    responseObject[tableName] = responseObject[tableName].concat(newRecordCollection);
                }
            }
        }
    }
    if (singleResponse && tableKeyValue && responseObject[tableName].length > 0) {
        responseObject = responseObject[tableName][0];
    }
    else if (singleResponse && tableKeyValue)
        responseObject = {};
    return responseObject;
}
function processFields(fieldCollection, colName, tableName, tableKey, tableKeyValue, resultCollection) {
    var result = {};
    for (var key in fieldCollection) {
        var value = fieldCollection[key];
        var newValue = getValue(value);
        if (!(newValue === undefined)) {
            if (colName == tableName)
                result[key] = newValue;
        }
        else if (key == tableName && value.arrayValue) {
            processFields(value.arrayValue.values, key, tableName, tableKey, tableKeyValue, resultCollection);
        }
        else if (colName == tableName && value.mapValue) {
            processFields(value.mapValue.fields, colName, tableName, tableKey, tableKeyValue, resultCollection);
        }
    }
    if (colName == tableName && Object.keys(result).length > 0 && (!tableKeyValue || (result[tableKey] == tableKeyValue)))
        resultCollection.push(result);
}
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
    exports.convertFsRequest = convertFsRequest;
    exports.convertFsResponse = convertFsResponse;
    exports.convertFsNestedResponse = convertFsNestedResponse;
}
