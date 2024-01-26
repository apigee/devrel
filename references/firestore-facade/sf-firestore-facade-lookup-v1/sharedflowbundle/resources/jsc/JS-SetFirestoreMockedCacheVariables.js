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

// set variable *** flow.lookup.hit ***
context.setVariable('flow.lookup.hit','true');

// mock content
var content = {
    message: "mock content",
    details: "content retrieved from mocked firestore db",
    code: "FIRESTORE-MOCK001"
}

// set variable *** flow.lookup.content ***
context.setVariable('flow.lookup.content',JSON.stringify(content));

// set variable *** flow.lookup.status.code ***
context.setVariable('flow.lookup.status.code',200);
