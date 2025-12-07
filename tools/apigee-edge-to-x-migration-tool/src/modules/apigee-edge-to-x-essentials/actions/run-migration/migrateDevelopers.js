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
import mergeData from "../../../../utils/mergeData.js";

// Import necessary modules and utilities for developer migration
import {
  getApigeeEdgeDevelopers
} from "../../../../gateway-clients/apigee-edge/developers/index.js";
import {
  getApigeeXDevelopers,
  getApigeeXDeveloperById,
  createApigeeXDeveloper,
  deleteApigeeXDeveloperById,
  updateApigeeXDeveloperById
} from "../../../../gateway-clients/apigee-x/developers/index.js";
import {
  logMigrationStatus,
  handleMigrationError,
  markAsDuplicate,
  logDeviations
} from "./migrationLogHelper.js";

/**
 * Migrate developers from Apigee Edge to Apigee X.
 *
 * @param {Object} options - Options for migration, including executionModel.
 */
async function migrateDevelopers(options) {
  try {
    // Fetch developers from Apigee Edge
    const edgeDevelopers = await getApigeeEdgeDevelopers(Context.sourceClient);
    let xDeveloperEmails = [];

    // Fetch and extract developer emails from Apigee X
    const developerEmails = await getApigeeXDevelopers(Context.destinationClient);
    if (developerEmails && developerEmails.length > 0) {
      xDeveloperEmails = developerEmails.map(developer => developer.email);
    }

    // Initialize a counter for migration summary
    const counter = {
      entityType: 'Developer',
      edgeTotal: edgeDevelopers.length,
      migrated: 0,
      duplicates: 0,
      failed: 0
    };

    // Process each developer from Apigee Edge
    for (let developer of edgeDevelopers) {
      await processDeveloper(developer, xDeveloperEmails, options.executionModel, counter);
    }

    // Log the final migration summary
    console.log(counter);
  } catch (error) {
    console.error("Error migrating developers:", error);
  }
}

/**
 * Process an individual developer based on the execution model.
 *
 * @param {Object} developer - Developer from Apigee Edge.
 * @param {Array} xDeveloperEmails - List of developer emails in Apigee X.
 * @param {String} executionModel - The execution model ('create', 'merge', 'overwrite').
 * @param {Object} counter - Migration summary counter.
 */
async function processDeveloper(developer, xDeveloperEmails, executionModel, counter) {
  switch (executionModel) {
    case 'create':
      await handleCreateDeveloper(developer, xDeveloperEmails, counter);
      break;
    case 'merge':
      await handleMergeDeveloper(developer, xDeveloperEmails, counter);
      break;
    case 'overwrite':
      await handleOverwriteDeveloper(developer, xDeveloperEmails, counter);
      break;
    default:
      console.error("Invalid execution model specified for developer.");
  }
}

/**
 * Handle the 'create' execution model for developer migration.
 *
 * @param {Object} developer - Developer from Apigee Edge.
 * @param {Array} xDeveloperEmails - List of developer emails in Apigee X.
 * @param {Object} counter - Migration summary counter.
 */
async function handleCreateDeveloper(developer, xDeveloperEmails, counter) {
  if (!xDeveloperEmails.includes(developer.email)) {
    try {
      const developerPayload = await prepareDeveloperPayload(developer);
      const x_developer = await createApigeeXDeveloper(Context.destinationClient, JSON.stringify(developerPayload));
      counter.migrated++;
      logMigrationStatus('Developer', developer.email, 'Migrated', x_developer.createdAt);
    } catch (creationError) {
      handleMigrationError('Developer', developer.email, creationError, counter);
    }
  } else {
    markAsDuplicate('Developer', developer.email, counter);
  }
}

/**
 * Handle the 'merge' execution model for developer migration.
 *
 * @param {Object} developer - Developer from Apigee Edge.
 * @param {Array} xDeveloperEmails - List of developer emails in Apigee X.
 * @param {Object} counter - Migration summary counter.
 */
async function handleMergeDeveloper(developer, xDeveloperEmails, counter) {
  if (xDeveloperEmails.includes(developer.email)) {
    try {
      // Prepare the developer payload from Edge
      const edgeDeveloper = await prepareDeveloperPayload(developer);

      // Fetch the existing developer from Apigee X
      const existingXDeveloper = await getApigeeXDeveloperById(Context.destinationClient, developer.email);
      const xDeveloperFormatted = await prepareDeveloperPayload(existingXDeveloper);

      // Merge the existing X developer data with Edge developer data
      const mergeResults = await mergeData(xDeveloperFormatted, edgeDeveloper, true);

      // If merged data exists, update the developer in Apigee X
      if (mergeResults.mergedData) {
        const mergedDeveloper = mergeResults.mergedData;
        const x_developer = await updateApigeeXDeveloperById(Context.destinationClient, mergedDeveloper.email, JSON.stringify(mergedDeveloper));
        counter.migrated++;

        // Log the migration status and deviations
        logMigrationStatus('Developer', mergedDeveloper.email, 'Migrated', x_developer.createdAt);
        logDeviations('Developer', mergedDeveloper.email, mergeResults, x_developer.createdAt);
      } else {
        markAsDuplicate('Developer', developer.email, counter);
      }
    } catch (mergeError) {
      // Handle any errors during the merge process
      handleMigrationError('Developer', developer.email, mergeError, counter);
    }
  } else {
    // If developer does not exist in Apigee X, create a new one
    await handleCreateDeveloper(developer, xDeveloperEmails, counter);
  }
}

/**
 * Handle the 'overwrite' execution model for developer migration.
 *
 * @param {Object} developer - Developer from Apigee Edge.
 * @param {Array} xDeveloperEmails - List of developer emails in Apigee X.
 * @param {Object} counter - Migration summary counter.
 */
async function handleOverwriteDeveloper(developer, xDeveloperEmails, counter) {
  if (xDeveloperEmails.includes(developer.email)) {
    try {
      // Prepare the developer payload from Edge
      const edgeDeveloper = await prepareDeveloperPayload(developer);

      // Overwrite the existing developer in Apigee X with Edge data
      const x_developer = await updateApigeeXDeveloperById(Context.destinationClient, edgeDeveloper.email, JSON.stringify(edgeDeveloper));
      counter.migrated++;

      // Log the successful migration
      logMigrationStatus('Developer', developer.email, 'Migrated', x_developer.createdAt);
    } catch (overwriteError) {
      // Handle any errors during the overwrite process
      handleMigrationError('Developer', developer.email, overwriteError, counter);
    }
  } else {
    // If developer does not exist in Apigee X, create a new one
    await handleCreateDeveloper(developer, xDeveloperEmails, counter);
  }
}

/**
 * Prepare the payload for a developer.
 *
 * @param {Object} developer - Developer data.
 * @returns {Object} - Prepared developer payload.
 */
async function prepareDeveloperPayload(developer) {
  const developerPayload = developer;

  // Remove specific properties not needed for Apigee X
  delete developerPayload['organizationName'];
  delete developerPayload['createdBy'];
  delete developerPayload['lastModifiedBy'];

  return developerPayload;
}

// Export the migrateDevelopers function as default
export default migrateDevelopers;