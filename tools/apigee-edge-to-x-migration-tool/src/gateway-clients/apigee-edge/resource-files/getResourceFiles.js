/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import ApigeeEdgeClient from '../ApigeeEdgeClient.js';

/**
 * Get all resource files in the org.
 * 
 * @param {ApigeeEdgeClient} apigeeEdgeClient 
 * @param {string} environment
 * @param {(resourcefile) => Promise<void|null>} callback 
 * @returns 
 */
async function getApigeeEdgeResourceFiles(apigeeEdgeClient, environment, callback = null) {
  return apigeeEdgeClient.get(`/environments/${environment}/resourcefiles`).then(async response => {
    const resourceFiles = response?.resourceFile ?? [];

    for (const resourceFile of resourceFiles) {
      if (typeof callback === 'function') {
        await callback(resourceFile);
      }
    }

    return resourceFiles;
  });
}

export default getApigeeEdgeResourceFiles;