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
import ApigeeEdgeClient from "../ApigeeEdgeClient.js";

/**
 * 
 * @param {ApigeeEdgeClient} apigeeEdgeClient 
 * @param {(string) => Promise<void|null>} callback 
 * @param {string|null} startKey 
 * @returns {array<string>}
 */
export default async function getApigeeEdgeApiProxyNames(apigeeEdgeClient, callback = null, startKey = null) {
  const query = {
    count: 100 // Max results that Apigee cloud can return at once
  };

  if (startKey) {
    query.startKey = startKey;
  }

  return apigeeEdgeClient.get(`/apis?${querystring.stringify(query)}`).then(async proxies => {
    if (startKey) {
      // Remove the first item from the list, since it will be the last item from the list on the previous call.
      proxies.shift();
    }

    if (typeof callback === 'function') {
      for (let proxy of proxies) {
        await callback(proxy);
      }
    }

    const lastProxyName = proxies.length > 0 ? proxies.at(proxies.length - 1) : null;

    if (lastProxyName && lastProxyName.length > 0) {
      // Keep fetching until there are no more results\
      return getApigeeEdgeApiProxyNames(apigeeEdgeClient, callback, lastProxyName).then(results => proxies.concat(results));
    }

    return proxies;
  });
}
