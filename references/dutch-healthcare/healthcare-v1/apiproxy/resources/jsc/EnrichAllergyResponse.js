/* eslint require-jsdoc: 0 */
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

function onComplete(response,error) {
    if (!error) {

      // update response payload with new patient name
      var payload = JSON.parse(context.getVariable("response.content"));
      payload.patient.display = response.content.asJSON.args.name;
      context.setVariable("response.content", JSON.stringify(payload))

     } else {
       throw error;
     }
}

// Make an additional request
httpClient.get("https://httpbin.org/get?name=Mediated Display Name", onComplete);
