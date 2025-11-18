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
import ApigeeXClient from "../ApigeeXClient.js";

/**
 * 
 * @param {ApigeeXClient} apigeeXClient 
 * @param {*} bundle
 * @returns {Promise<string>} The filepath for the downloaded API proxy bundle
 */
export default async function validateApiProxyBundle(apigeeXClient, proxyName, bundle) {
  const query = querystring.stringify({
    name: proxyName,
    action: 'validate'
  })

  return apigeeXClient.post(`/apis?${query}`, bundle);
}
