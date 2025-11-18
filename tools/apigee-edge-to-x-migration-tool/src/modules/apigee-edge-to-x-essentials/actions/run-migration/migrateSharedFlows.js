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
  getApigeeEdgeSharedFlowNames,
  getApigeeEdgeSharedFlowBundle,
  getApigeeEdgeSharedFlowByName,
  getApigeeEdgeSharedFlowDeployments
} from "../../../../gateway-clients/apigee-edge/shared-flows/index.js";
import {
  getApigeeXSharedFlowNames,
  getApigeeXSharedFlowDeployments,
  getSharedFlowRevisionDeployment,
  validateApigeeXSharedFlowBundle,
  createApigeeXSharedFlow,
  deleteApigeeXSharedFlowByName,
  deploySharedFlowRevision,
  undeploySharedFlowRevision
} from "../../../../gateway-clients/apigee-x/shared-flows/index.js";
import { logMigrationStatus, handleMigrationError, markAsDuplicate } from "./migrationLogHelper.js";

/**
 * Migrate shared flows from Apigee Edge to Apigee X using the specified execution model.
 *
 * @param {Object} options - Options for migration, including executionModel.
 */
async function migrateSharedFlows(options) {
  try {
    // Retrieve shared flow names from Apigee Edge and Apigee X
    const edge_sharedFlowNames = await getApigeeEdgeSharedFlowNames(Context.sourceClient);
    const sharedFlowNames = await getApigeeXSharedFlowNames(Context.destinationClient);
    let x_sharedFlowNames = [];

    // Check if sharedFlowNames.sharedFlows is not an empty array
    if (sharedFlowNames.sharedFlows && sharedFlowNames.sharedFlows.length > 0) {
      x_sharedFlowNames = sharedFlowNames.sharedFlows.map(flow => flow.name);
    }

    // Initialize a counter for migration summary
    const counter = {
      entityType: 'SharedFlow',
      edgeTotal: edge_sharedFlowNames.length,
      migrated: 0,
      duplicates: 0,
      skipped: 0,
      failed: 0
    };

    // Process each shared flow
    for (let flowName of edge_sharedFlowNames) {
      await processSharedFlow(flowName, x_sharedFlowNames, options.executionModel, counter);
    }

    // Log the final migration summary
    console.log(counter);
  } catch (error) {
    console.error("Error migrating shared flows:", error);
  }
}

/**
 * Process an individual shared flow based on the execution model.
 *
 * @param {String} flowName - Shared flow name from Apigee Edge.
 * @param {Array} x_sharedFlowNames - List of shared flow names in Apigee X.
 * @param {String} executionModel - The execution model ('create', 'merge', 'overwrite').
 * @param {Object} counter - Migration summary counter.
 */
async function processSharedFlow(flowName, x_sharedFlowNames, executionModel, counter) {
  switch (executionModel) {
    case 'create':
      await handleCreateSharedFlow(flowName, x_sharedFlowNames, counter);
      break;
    case 'merge':
      console.log("Synchronize is not a valid option for Shared Flows");
      break;
    case 'overwrite':
      await handleOverwriteSharedFlow(flowName, x_sharedFlowNames, counter);
      break;
    default:
      console.error("Invalid execution model specified.");
  }
}

/**
 * Handle the 'create' execution model for shared flow migration.
 *
 * @param {String} flowName - Shared flow name from Apigee Edge.
 * @param {Array} x_sharedFlowNames - List of shared flow names in Apigee X.
 * @param {Object} counter - Migration summary counter.
 */
async function handleCreateSharedFlow(flowName, x_sharedFlowNames, counter) {
  if (!x_sharedFlowNames.includes(flowName)) {
    try {
      // Retrieve shared flow and deployment details from Apigee Edge
      const environmentMap = JSON.parse(process.env.apigee_environment_map || '{}');
      const sharedFlow = await getApigeeEdgeSharedFlowByName(Context.sourceClient, flowName);
      const edgeSharedFlowDeployments = await getApigeeEdgeSharedFlowDeployments(Context.sourceClient, flowName);
      const edgeDeployments = [];

      for (const env of edgeSharedFlowDeployments.environment || []) {
        for (const rev of env.revision) {
          edgeDeployments.push({
            environment: env.name,
            revision: rev.name
          });
        }
      }
      let revisionMigrated = 0;
      let envMigratedTotal = 0;
      // Process each revision for the shared flow
      for (const revisionId of sharedFlow.revision) {
        const bundleFilePath = await getApigeeEdgeSharedFlowBundle(
          Context.sourceClient,
          flowName,
          revisionId
        );

        const buffer = await fs.readFile(bundleFilePath);

        if (!Buffer.isBuffer(buffer)) {
          console.error(`Not a buffer`);
        }

        try {
          // Create shared flow in Apigee X
          const x_sharedFlow = await createApigeeXSharedFlow(Context.destinationClient, flowName, buffer);
          revisionMigrated++;
          let envMigrated = 0;
          // Deploy to appropriate environments in X
          for (const deployments of edgeDeployments) {
            const deployedRevision = deployments.revision;
            const edgeEnvironment = deployments.environment;
            const xEnvironments = environmentMap[edgeEnvironment];

            if (!xEnvironments) {
              console.warn(`Skipping deployment for '${flowName}' - No mapping for Edge environment '${edgeEnvironment}'.`);
              counter.skipped++;
              continue;
            }

            if (Number(revisionId) === Number(deployedRevision)) {
              const deploy = await deploySharedFlowRevision(Context.destinationClient, xEnvironments, flowName, x_sharedFlow.revision);

              let deploymentStatus = '';
              const pollInterval = 15000; // 15 seconds interval

              // Polling until deployment is ready
              while (deploymentStatus !== 'READY') {
                const deployment = await getSharedFlowRevisionDeployment(Context.destinationClient, xEnvironments, flowName, x_sharedFlow.revision);
                deploymentStatus = deployment.state;

                if (deploymentStatus !== 'READY') {
                  await setTimeout(pollInterval); // Wait before checking again
                }
              }

              if (deploymentStatus === 'READY') {
                envMigrated++;
                logMigrationStatus('SharedFlow', flowName, 'Migrated', x_sharedFlow.createdAt);
              }
            }
          }
          envMigratedTotal += envMigrated; //totalDeployments
        } catch (creationError) {
          console.log(`creationError : ${flowName}`);
          handleMigrationError('SharedFlow', flowName, creationError, counter);
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
      console.log(`error: ${flowName}`);
      handleMigrationError('SharedFlow', flowName, error, counter);
    }
  } else {
    markAsDuplicate('SharedFlow', flowName, counter);
  }
}

/**
 * Handle the 'overwrite' execution model for shared flow migration.
 *
 * @param {String} flowName - Shared flow name from Apigee Edge.
 * @param {Array} x_sharedFlowNames - List of shared flow names in Apigee X.
 * @param {Object} counter - Migration summary counter.
 */
async function handleOverwriteSharedFlow(flowName, x_sharedFlowNames, counter) {
  if (x_sharedFlowNames.includes(flowName)) {
    // Perform clean up in Apigee X.
    try {
      // Identify the deployed environments and revisions.
      const xSharedFlowDeployments = await getApigeeXSharedFlowDeployments(Context.destinationClient, flowName);

      // Undeploy and delete shared flow Apigee X
      if (Array.isArray(xSharedFlowDeployments.deployments)) {
        for (const deployment of xSharedFlowDeployments.deployments) {
          await undeploySharedFlowRevision(Context.destinationClient, deployment.environment, flowName, deployment.revision);
        }
      }
      await deleteApigeeXSharedFlowByName(Context.destinationClient, flowName);
    } catch (overwriteError) {
      handleMigrationError('SharedFlow', flowName, overwriteError, counter);
    }
  }

  // Create new entity in X
  await handleCreateSharedFlow(flowName, [], counter);
}

// Export the migrateSharedFlows function as default
export default migrateSharedFlows;