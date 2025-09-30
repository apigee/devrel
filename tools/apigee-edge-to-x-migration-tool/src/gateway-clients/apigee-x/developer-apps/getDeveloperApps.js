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


import querystring from 'node:querystring';
import ApigeeXClient from '../ApigeeXClient.js';

/**
 * 
 * @param {ApigeeXClient} apigeeXClient 
 * @param {(app) => Promise<void|null>} callback 
 * @param {string} startKey 
 * @returns 
 */
async function getApigeeXDeveloperApps(apigeeXClient, callback = null, startKey = null) {
  const limit = 1000; // Max results that Apigee public cloud can return at once

  const query = {
    expand: true,
    rows: limit,
    apptype: 'developer'
  };

  if (startKey) {
    query.startKey = startKey;
  }

  return apigeeXClient.get(`/apps?${querystring.stringify(query)}`).then(async response => {
    const developerApps = response?.app ?? [];

    if (startKey) {
      // Remove the first item from the list, since it will be the last item from the list on the previous call.
      developerApps.shift();
    }

    if (typeof callback === 'function') {
      for (let developerApp of developerApps) {
        await callback(developerApp);
      }
    }

    const lastAppId = developerApps.length > 0 ? developerApps.at(developerApps.length - 1).appId : null;

    if (lastAppId && lastAppId.length > 0) {
      // Keep fetching until there are no more results\
      return getApigeeXDeveloperApps(apigeeXClient, callback, lastAppId).then(results => developerApps.concat(results));
    }

    return developerApps;
  });
}

export default getApigeeXDeveloperApps;