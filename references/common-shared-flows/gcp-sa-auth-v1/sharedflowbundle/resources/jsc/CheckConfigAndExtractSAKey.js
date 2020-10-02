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
var scope = context.getVariable('gcp.scopes');
var targetAudience = context.getVariable('gcp.target_audience');
var serviceAccountKeyJson = context.getVariable('private.gcp.service_account.key');

// Check if required variables are present
if (!targetAudience && !scope) {
    context.setVariable('gcp.service_account.error_message',
        'Shared Flow requires either "gcp.scopes" or "target_audience" variable to be set. None provided.');
}
if (!!targetAudience && !!scope) {
    context.setVariable('gcp.service_account.error_message',
        'Shared Flow requires either "gcp.scopes" or "target_audience" variable to be set. Provided both.');
}
if (!serviceAccountKeyJson || serviceAccountKeyJson.length === 0) {
    context.setVariable('gcp.service_account.error_message',
        'Shared Flow required the GCP Service Account JSON key to be stored in a "private.gcp.service_account.key" variable');
}

try {
    var serviceAccountKey = JSON.parse(serviceAccountKeyJson);
    for (var prop in serviceAccountKey) {
        if ({}.hasOwnProperty.call(serviceAccountKey, prop)) {
            context.setVariable('private.gcp.service_account.' + prop, serviceAccountKey[prop]);
        }
    }
} catch (e) {
    context.setVariable('gcp.service_account.error_message', e.message)
}
