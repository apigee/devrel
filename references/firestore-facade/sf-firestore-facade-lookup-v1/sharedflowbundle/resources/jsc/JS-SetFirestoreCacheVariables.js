/**
  Copyright 2023 Google LLC
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
      https://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

// has a content been retrieved from firestore cache or not ?
var isDataRetrievedFromCache = (context.getVariable('servicecallout.SC-Lookup-FirestoreCache.failed').toString().toLowerCase() === 'true');
// set variable *** flow.lookup.hit ***
context.setVariable('flow.lookup.hit',!(isDataRetrievedFromCache));

var content = null;
if ( !(isDataRetrievedFromCache) ) {
    // get content as a string as this is what we want (a JSON stringified content!)
    content = JSON.parse(context.getVariable('firestoreCacheResponse.content')).fields.data.stringValue;
}
// set variable *** flow.lookup.content ***
context.setVariable('flow.lookup.content',content);

// set variable *** flow.lookup.status.code ***
context.setVariable('flow.lookup.status.code',context.getVariable("firestoreCacheResponse.status.code"));
