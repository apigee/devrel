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

// has a content been stored in firestore cache or not ?
var isDataStoredInCache = (context.getVariable('servicecallout.SC-PopulateCache.failed').toString().toLowerCase() === 'true');
// set variable *** flow.populate.success ***
context.setVariable('flow.populate.success',!(isDataStoredInCache));

var content = null;
if ( !(isDataStoredInCache) ) {
    // get content as a string
    content = JSON.parse(context.getVariable('firestoreCacheResponse.content')).fields.data.stringValue;
}
// set variable *** flow.populate.content ***
context.setVariable('flow.populate.content',content);

// set variable *** flow.populate.status.code ***
context.setVariable('flow.populate.status.code',context.getVariable("firestoreCacheResponse.status.code"));

// set variable *** flow.populate.cachekey ***
context.setVariable('flow.populate.cachekey',context.getVariable("flow.basePath")+'/'+context.getVariable("flow.pathSuffix"));

// set variable *** flow.populate.extcache.documentid ***
context.setVariable('flow.populate.extcache.documentid',context.getVariable("flow.pathSuffix"));

// set variable *** flow.populate.extcache.collectionid ***
context.setVariable('flow.populate.extcache.collectionid',context.getVariable("flow.basePath"));