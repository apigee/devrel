/**
 * Copyright 2022 Google LLC
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

const pathOp = context.getVariable('oas.pathoperation');

if (pathOp === 'CONSTANT_ADDRESS') {
    context.setVariable('target.copy.pathsuffix', 'false');
} else if (pathOp === 'APPEND_PATH_TO_ADDRESS') {
    const targetBaseUrl = context.getVariable('target.url')
    const proxyBasePath = context.getVariable('proxy.basepath')
    context.setVariable('target.url', targetBaseUrl + proxyBasePath);
}
