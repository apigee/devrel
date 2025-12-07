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

/**
 * Deploys a specific revision of an Shared Flow to a given environment in Apigee X.
 *
 * @param {ApigeeXClient} apigeeXClient - An instance of the ApigeeXClient, used to interact with the Apigee X API.
 * @param {string} apigeeEnvironment - The environment in Apigee X where the Shared Flow should be undeployed (e.g., 'test', 'prod').
 * @param {string} sharedFlowName - The name of the Shared Flow to be undeployed.
 * @param {string} revision - The specific revision number of the Shared Flow to undeploy.
 * @returns {Promise<string>} A promise that resolves to a string confirming the undeployment of the Shared Flow revision.
 */
export default async function undeploySharedFlowRevision(apigeeXClient, apigeeEnvironment, sharedFlowName, revision) {
  return apigeeXClient.delete(`/environments/${apigeeEnvironment}/sharedflows/${sharedFlowName}/revisions/${revision}/deployments`);
}