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

import ApigeeXClient from "../ApigeeXClient.js";
import querystring from 'node:querystring';

/**
 * Deploys a specific revision of an Shared Flow to a given environment in Apigee X.
 *
 * @param {ApigeeXClient} apigeeXClient - An instance of the ApigeeXClient, used to interact with the Apigee X API.
 * @param {string} apigeeEnvironment - The environment in Apigee X where the Shared Flow should be deployed (e.g., 'test', 'prod').
 * @param {string} sharedFlowName - The name of the Shared Flow to be deployed.
 * @param {string} revision - The specific revision number of the Shared Flow to deploy.
 * @returns {Promise<string>} A promise that resolves to a string confirming the deployment of the Shared Flow revision.
 */
export default async function deploySharedFlowRevision(apigeeXClient, apigeeEnvironment, sharedFlowName, revision, override = true) {
  const query = querystring.stringify({
    override: override
  })
  return apigeeXClient.post(`/environments/${apigeeEnvironment}/sharedflows/${sharedFlowName}/revisions/${revision}/deployments?${query}`);
}