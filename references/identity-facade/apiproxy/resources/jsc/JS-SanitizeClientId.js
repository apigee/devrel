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

// encodeURI the client_id query parameter's value
var clientId = context.getVariable('request.queryparam.client_id');
if (clientId !== undefined && clientId !== null) {
  // uri encoding of the client_id's value
  context.setVariable('request.queryparam.client_id',encodeURIComponent(clientId));
}