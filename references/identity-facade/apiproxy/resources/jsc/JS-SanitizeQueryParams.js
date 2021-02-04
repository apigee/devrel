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

// function used to retrieve sanitized query parameters and values
function getQueryParameters(query) {
    var keyValuePairs = query.split(/[&]/g);
    var params = {};
    for (var i = 0, n = keyValuePairs.length; i < n; ++i) {
      var m = keyValuePairs[i].match(/^([^=]+)(?:=([\s\S]*))?/);
      // only add defined values
      if (m && m[1] !== undefined && m[2] !== undefined) {
        var key = sanitize(m[1]);
        params[key] = sanitize(m[2]);
      }
    }
    return params;
  }
  
// function used to sanitize a string
function sanitize(str) {
    // uri decoding and trim
    return decodeURIComponent(str).trim();
}
  
// get the query string from 'request.querystring' variable
var queryString = context.getVariable('request.querystring');
// test the query string and evaluate the sanitized result
var sanitizedData = (queryString !== null && queryString !== undefined && queryString !== '')?getQueryParameters(queryString):{};
// are there any sanitized data?
var size = Object.keys(sanitizedData).length;

if (size > 0) { // if sanitized data, then recreate the query params
    var arrayOfKeys = Object.keys(sanitizedData);
    for (var i = 0; i< arrayOfKeys.length; i++ ) {
        var key = arrayOfKeys[i];
        var value = sanitizedData[key].toString();
        // set query param as context variable
        context.setVariable('request.queryparam.'+key,value);
    }
}