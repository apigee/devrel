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

// Import necessary modules and utilities
import fs from 'fs/promises';
import { setTimeout } from 'timers/promises';
import Context from "../../../../utils/context.js";
import {
  getApigeeEdgeApiProxyNames,
  getApigeeEdgeApiProxyBundle,
  getApigeeEdgeApiProxyByName,
  getApigeeEdgeApiProxyDeployments
} from "../../../../gateway-clients/apigee-edge/api-proxies/index.js";
import {
  getApigeeXApiProxyNames,
  getApigeeXApiProxyDeployments,
  getApiProxyRevisionDeployment,
  createApigeeXApiProxy,
  deleteApigeeXApiProxyByName,
  deployApiRevision,
  undeployApiProxyRevision
} from "../../../../gateway-clients/apigee-x/api-proxies/index.js";
import {
  logMigrationStatus,
  handleMigrationError,
  markAsDuplicate
} from "./migrationLogHelper.js";

/**
 * Migrate API proxies from Apigee Edge to Apigee X using the specified execution model.
 *
 * @param {Object} options - Options for migration, including executionModel.
 */
async function migrateApiProxies(options) {
  try {
    // Retrieve API proxy names from Apigee Edge and Apigee X
    const edge_proxyNames = await getApigeeEdgeApiProxyNames(Context.sourceClient);
    const apiProxyNames = await getApigeeXApiProxyNames(Context.destinationClient);
    let x_apiProxyNames = [];

    // Check if apiProxyNames.proxies is not an empty array
    if (apiProxyNames.proxies && apiProxyNames.proxies.length > 0) {
      x_apiProxyNames = apiProxyNames.proxies.map(proxy => proxy.name);
    }

    // Initialize a counter for migration summary
    const counter = {
      entityType: 'APIProxy',
      edgeTotal: edge_proxyNames.length,
      migrated: 0,
      duplicates: 0,
      skipped: 0,
      failed: 0
    };

    // Process each API proxy from Apigee Edge
    for (let proxyName of edge_proxyNames) {
      await processApiProxy(proxyName, x_apiProxyNames, options.executionModel, counter);
    }

    // Log the final migration summary
    console.log(counter);
  } catch (error) {
    console.error("Error migrating API proxies:", error);
  }
}

/**
 * Process an individual API proxy based on the execution model.
 *
 * @param {String} proxyName - API proxy name from Apigee Edge.
 * @param {String} executionModel - The execution model ('create', 'merge', 'overwrite').
 * @param {Object} counter - Migration summary counter.
 */
async function processApiProxy(proxyName, x_apiProxyNames, executionModel, counter) {
  switch (executionModel) {
    case 'create':
      await handleCreateProxy(proxyName, x_apiProxyNames, counter);
      break;
    case 'merge':
      console.log("Synchronize is not a valid option for API Proxies");
      break;
    case 'overwrite':
      await handleOverwriteProxy(proxyName, x_apiProxyNames, counter);
      break;
    default:
      console.error("Invalid execution model specified.");
  }
}

/**
 * Handle the 'create' execution model for API proxy migration.
 *
 * @param {String} proxyName - API proxy name from Apigee Edge.
 * @param {Array} x_apiProxyNames - List of API Proxy names in Apigee X.
 * @param {Object} counter - Migration summary counter.
 */
async function handleCreateProxy(proxyName, x_apiProxyNames, counter) {
  if (!x_apiProxyNames.includes(proxyName)) {
    try {
      // Retrieve proxy and deployment details from Apigee Edge
      const environmentMap = JSON.parse(process.env.apigee_environment_map || '{}');
      const proxy = await getApigeeEdgeApiProxyByName(Context.sourceClient, proxyName);
      const edgeProxyDeployments = await getApigeeEdgeApiProxyDeployments(Context.sourceClient, proxyName);
      const edgeDeployments = [];

      // Gather all deployment information
      for (const env of edgeProxyDeployments.environment || []) {
        for (const rev of env.revision) {
          edgeDeployments.push({
            environment: env.name,
            revision: rev.name
          });
        }
      }
      let revisionMigrated = 0;
      let envMigratedTotal = 0;
      // Process each revision for the proxy
      for (const revisionId of proxy.revision) {
        const bundleFilePath = await getApigeeEdgeApiProxyBundle(
          Context.sourceClient,
          proxyName,
          revisionId
        );

        const buffer = await fs.readFile(bundleFilePath);

        if (!Buffer.isBuffer(buffer)) {
          console.error(`Not a buffer`);
        }

        try {
          // Create API proxy in Apigee X
          const x_proxy = await createApigeeXApiProxy(Context.destinationClient, proxyName, buffer);
          revisionMigrated++;
          let envMigrated = 0;
          // Deploy to appropriate environments in X
          for (const deployments of edgeDeployments) {
            const deployedRevision = deployments.revision;
            const edgeEnvironment = deployments.environment;
            const xEnvironments = environmentMap[edgeEnvironment];

            if (!xEnvironments) {
              console.warn(`Skipping deployment for '${proxyName}' - No mapping for Edge environment '${edgeEnvironment}'.`);
              counter.skipped++;
              continue;
            }

            if (Number(revisionId) === Number(deployedRevision)) {
              const deploy = await deployApiRevision(Context.destinationClient, xEnvironments, proxyName, x_proxy.revision);

              let deploymentStatus = '';
              const pollInterval = 15000; // 15 seconds interval

              // Polling until deployment is ready
              while (deploymentStatus !== 'READY') {
                const deployment = await getApiProxyRevisionDeployment(Context.destinationClient, xEnvironments, proxyName, x_proxy.revision);
                deploymentStatus = deployment.state;

                if (deploymentStatus !== 'READY') {
                  await setTimeout(pollInterval); // Wait before checking again
                }
              }

              if (deploymentStatus === 'READY') {
                envMigrated++;
                logMigrationStatus('APIProxy', proxyName, 'Migrated', x_proxy.createdAt)
              }
            }
          }
          envMigratedTotal += envMigrated; //totalDeployments
        } catch (creationError) {
          handleMigrationError('APIProxy', proxyName, creationError, counter);
        }
      }
      if (revisionMigrated > 0) {
        if (edgeDeployments.length === 0) {
          counter.migrated++;   // No deployments in Edge, but import succeeded
        } else if (envMigratedTotal === edgeDeployments.length) {
          counter.migrated++;   // All environments migrated
        }
      }
    } catch (error) {
      handleMigrationError('APIProxy', proxyName, error, counter);
    }
  } else {
    markAsDuplicate('APIProxy', proxyName, counter);
  }
}

/**
 * Handle the 'overwrite' execution model for API proxy migration.
 *
 * @param {String} proxyName - API proxy name from Apigee Edge.
 * @param {Array} x_apiProxyNames - List of API proxy names in Apigee X.
 * @param {Object} counter - Migration summary counter.
 */
async function handleOverwriteProxy(proxyName, x_apiProxyNames, counter) {

  if (x_apiProxyNames.includes(proxyName)) {
    try {
      // Retrieve deployments and undeploy from Apigee X
      const xProxyDeployments = await getApigeeXApiProxyDeployments(Context.destinationClient, proxyName);

      if (Array.isArray(xProxyDeployments.deployments)) {
        for (const deployment of xProxyDeployments.deployments) {
          await undeployApiProxyRevision(Context.destinationClient, deployment.environment, proxyName, deployment.revision);
        }
      }
      // Delete the API proxy in Apigee X
      await deleteApigeeXApiProxyByName(Context.destinationClient, proxyName);
    } catch (overwriteError) {
      handleMigrationError('APIProxy', proxyName, overwriteError, counter);
    }
  }
  // Proceed to create a new entity in X
  await handleCreateProxy(proxyName, [], counter);
}

// Export the migrateApiProxies function as default
export default migrateApiProxies;