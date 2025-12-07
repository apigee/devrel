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
 * @param {(developer)} callback 
 * @param {string} startKey 
 * @returns 
 */
async function getApigeeXDevelopers(apigeeXClient, callback = null, startKey = null) {
  const limit = 1000; // Max results that Apigee cloud can return at once

  const query = {
    expand: true,
    count: limit
  };

  if (startKey) {
    query.startKey = startKey;
  }

  return apigeeXClient.get(`/developers?${querystring.stringify(query)}`).then(async response => {
    const developers = response?.developer ?? [];

    if (startKey) {
      // Remove the first item from the list, since it will be the last item from the list on the previous call.
      developers.shift();
    }

    if (typeof callback === 'function') {
      for (let developer of developers) {
        callback(developer);
      }
    }

    const lastEmail = developers.length > 0 ? developers.at(developers.length - 1).email : null;

    if (lastEmail && lastEmail.length > 0) {
      // Keep fetching until there are no more results\
      return getApigeeXDevelopers(apigeeXClient, callback, lastEmail).then(results => developers.concat(results));
    }

    return developers;
  });
}

export default getApigeeXDevelopers;