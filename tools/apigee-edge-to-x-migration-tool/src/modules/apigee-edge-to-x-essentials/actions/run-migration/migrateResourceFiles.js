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
import Context from "../../../../utils/context.js";
import fs from "fs/promises";
import { setTimeout } from "timers/promises";

import {
  getApigeeEdgeResourceFiles,
  getApigeeEdgeResourceFileById
} from "../../../../gateway-clients/apigee-edge/resource-files/index.js";

import {
  getApigeeXResourceFiles,
  createApigeeXResourceFile,
  updateApigeeXResourceFile
} from "../../../../gateway-clients/apigee-x/resource-files/index.js";

import {
  logMigrationStatus,
  handleMigrationError,
  markAsDuplicate
} from "./migrationLogHelper.js";
import deleteApigeeXResourceFile from "../../../../gateway-clients/apigee-x/resource-files/deleteResourceFile.js";

/**
 * Migrate environment-level resource files from Apigee Edge to Apigee X.
 *
 * @param {Object} options - Options for migration, including executionModel.
 */
async function migrateResourceFiles(options) {
  try {
    // Load the environment mapping
    const environmentMap = JSON.parse(process.env.apigee_environment_map || '{}');
    const countersSummary = [];

    // Iterate over each environment mapping
    for (const [sourceEnv, targetEnv] of Object.entries(environmentMap)) {
      // Fetch resource files from Apigee Edge and Apigee X
      const edgeResourceFiles = await getApigeeEdgeResourceFiles(Context.sourceClient, sourceEnv);
      const xResourceFiles = await getApigeeXResourceFiles(Context.destinationClient, targetEnv);

      const x_resourceFileNames = xResourceFiles.map(r => `${r.type}/${r.name}`);
      const counter = {
        entityType: `ResourceFile (${sourceEnv} → ${targetEnv})`,
        edgeTotal: edgeResourceFiles.length,
        migrated: 0,
        duplicates: 0,
        skipped: 0,
        failed: 0
      };

      // Process each resource file
      for (let file of edgeResourceFiles) {
        const identifier = `${file.type}/${file.name}@${sourceEnv}`;
        await processResourceFile(file, identifier, sourceEnv, targetEnv, x_resourceFileNames, options.executionModel, counter);
      }

      countersSummary.push(counter);
    }
    // Log the counters summary for visibility
    console.log(countersSummary);
  } catch (error) {
    console.error("Error migrating environment-level resource files:", error);
  }
}

/**
 * Process an individual resource file based on the execution model.
 *
 * @param {Object} resourceFile - Resource file metadata from Apigee Edge.
 * @param {String} identifier - A unique ID for logging (e.g., "jsc/pathsetter.js@dev").
 * @param {String} sourceEnv - Source environment.
 * @param {String} targetEnv - Target environment.
 * @param {Array} x_resourceFileNames - List of resource file names already present in Apigee X.
 * @param {String} executionModel - The execution model ('create', 'merge', 'overwrite').
 * @param {Object} counter - Migration summary counter.
 */
async function processResourceFile(resourceFile, identifier, sourceEnv, targetEnv, x_resourceFileNames, executionModel, counter) {
  switch (executionModel) {
    case 'create':
      await handleCreateResourceFile(resourceFile, identifier, sourceEnv, targetEnv, x_resourceFileNames, counter);
      break;
    case 'merge':
      console.log("Synchronize is not a valid option for ResourceFile");
      break;
    case 'overwrite':
      await handleOverwriteResourceFile(resourceFile, identifier, sourceEnv, targetEnv, x_resourceFileNames, counter);
      break;
    default:
      console.error("Invalid execution model specified.");
  }
}

/**
 * Handle create mode for ResourceFiles.
 *
 * @param {Object} resourceFile - Resource file metadata from Apigee Edge.
 * @param {String} identifier - A unique ID for logging (e.g., "jsc/pathsetter.js@dev").
 * @param {String} sourceEnv - Source environment.
 * @param {String} targetEnv - Target environment.
 * @param {Array} x_resourceFileNames - List of resource file names already present in Apigee X.
 * @param {Object} counter - Migration summary counter.
 * @param {Boolean} [isOverwrite=false] - Flag to indicate if overwrite mode is enabled.
 */
async function handleCreateResourceFile(resourceFile, identifier, sourceEnv, targetEnv, x_resourceFileNames, counter, isOverwrite = false) {
  const shortName = `${resourceFile.type}/${resourceFile.name}`;
  if (isOverwrite || !x_resourceFileNames.includes(shortName)) {
    try {
      const resourceFileData = await getApigeeEdgeResourceFileById(Context.sourceClient, resourceFile.type, resourceFile.name, sourceEnv);
      await createApigeeXResourceFile(Context.destinationClient, targetEnv, resourceFile.type, resourceFile.name, resourceFileData);

      counter.migrated++;
      logMigrationStatus('ResourceFile', identifier, 'Migrated');
    } catch (err) {
      handleMigrationError('ResourceFile', identifier, err, counter);
    }
  } else {
    markAsDuplicate('ResourceFile', identifier, counter);
  }
}

/**
 * Handle overwrite mode for ResourceFiles.
 *
 * @param {Object} resourceFile - Resource file metadata from Apigee Edge.
 * @param {String} identifier - A unique ID for logging (e.g., "jsc/pathsetter.js@dev").
 * @param {String} sourceEnv - Source environment.
 * @param {String} targetEnv - Target environment.
 * @param {Array} x_resourceFileNames - List of resource file names already present in Apigee X.
 * @param {Object} counter - Migration summary counter.
 */
async function handleOverwriteResourceFile(resourceFile, identifier, sourceEnv, targetEnv, x_resourceFileNames, counter) {
  const shortName = `${resourceFile.type}/${resourceFile.name}`;

  if (x_resourceFileNames.includes(shortName)) {
    try {
      await deleteApigeeXResourceFile(Context.destinationClient, targetEnv, resourceFile.type, resourceFile.name, x_resourceFileNames);
    } catch (err) {
      handleMigrationError('ResourceFile', identifier, err, counter);
    }
  }

  await handleCreateResourceFile(resourceFile, identifier, sourceEnv, targetEnv, x_resourceFileNames, counter, true);
}

// Export the migrateResourceFiles function as default
export default migrateResourceFiles;