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

import {
  getApigeeEdgeDeveloperApps,
  getApigeeEdgeDeveloperAppById
} from "../../../../gateway-clients/apigee-edge/developer-apps/index.js";
import {
  getApigeeEdgeDevelopers
} from "../../../../gateway-clients/apigee-edge/developers/index.js";
import {
  getApigeeXDeveloperApps,
  getApigeeXDeveloperAppsByDeveloperId,
  getApigeeXDeveloperAppById,
  createDeveloperApp,
  updateDeveloperApp,
  createDeveloperAppKeys,
  updateDeveloperAppKeys,
  deleteDeveloperAppKeys,
  deleteApigeeXDeveloperAppById
} from "../../../../gateway-clients/apigee-x/developer-apps/index.js";
import {
  getApigeeXDevelopers
} from "../../../../gateway-clients/apigee-x/developers/index.js";
import {
  logMigrationStatus,
  handleMigrationError,
  markAsDuplicate,
  logDeviations
} from "./migrationLogHelper.js";

/**
 * Migrate developer apps from Apigee Edge to Apigee X.
 *
 * @param {Object} options - Options for migration, including developerEmailMap and executionModel.
 */
async function migrateDeveloperApps(options) {
  try {
    // Counter for tracking migration status
    const appCounter = {
      entityType: 'DeveloperApp',
      edgeTotal: 0,
      migrated: 0,
      skipped: 0,
      failed: 0,
      duplicates: 0,
      credentialErrors: 0
    };

    // Fetch developer apps from Apigee Edge
    const edgeDeveloperApps = await getApigeeEdgeDeveloperApps(Context.sourceClient);
    const xDeveloperApps = await getApigeeXDeveloperApps(Context.destinationClient);
    const edgeDevelopers = await getApigeeEdgeDevelopers(Context.sourceClient);

    // Process each developer app from Apigee Edge
    for (const edgeApp of edgeDeveloperApps) {
      appCounter.edgeTotal++;
      const appName = edgeApp.name;
      if (edgeApp.developerId !== undefined) {
        const developer = edgeDevelopers.find(developer => developer.developerId === edgeApp.developerId);
        const developerEmail = developer ? developer.email : null;
        await migrateDeveloperApp(edgeApp, xDeveloperApps, developerEmail, options.executionModel, appCounter);
      } else {
        console.warn(`Skipping migration of Company App: ${appName}`);
        appCounter.skipped++;
      }
    }

    // Log the summary of the migration process
    console.log(appCounter);
  } catch (error) {
    console.error("Error migrating Developer Apps:", error);
  }
}

/**
 * Helper function to migrate an individual developer app.
 *
 * @param {Object} edgeApp - The app to migrate.
 * @param {Array} xDeveloperApps - Developer apps from Apigee X.
 * @param {String} developerEmail - The email of the developer.
 * @param {String} executionModel - The execution model ('create', 'merge', 'overwrite').
 * @param {Object} counter - Counter for tracking migration status.
 */
async function migrateDeveloperApp(edgeApp, xDeveloperApps, developerEmail, executionModel, counter) {
  switch (executionModel) {
    case 'create':
      await handleCreateApp(edgeApp, xDeveloperApps, developerEmail, counter);
      break;
    case 'merge':
      await handleMergeApp(edgeApp, xDeveloperApps, developerEmail, counter);
      break;
    case 'overwrite':
      await handleOverwriteApp(edgeApp, xDeveloperApps, developerEmail, counter);
      break;
    default:
      console.error("Invalid execution model specified.");
  }
}

/**
 * Handle the 'create' execution model for Developer Apps migration.
 *
 * @param {Object} edgeApp - Developer Apps from Apigee Edge.
 * @param {Array} xDeveloperApps - List of Developer Apps names in Apigee X.
 * @param {String} developerEmail - The email of the developer.
 * @param {Object} counter - Migration summary counter.
 */
async function handleCreateApp(edgeApp, xDeveloperApps, developerEmail, counter) {
  const xDeveloperAppNames = (xDeveloperApps && xDeveloperApps.length > 0)
    ? xDeveloperApps.map(app => app.name)
    : [];

  if (!xDeveloperAppNames.includes(edgeApp.name)) {
    try {
      await processMigration(edgeApp, developerEmail, counter);
    } catch (creationError) {
      handleMigrationError('DeveloperApp', edgeApp.name, creationError, counter);
    }
  } else {
    markAsDuplicate('DeveloperApp', edgeApp.name, counter);
  }
}

/**
 * Handle the 'merge' execution model for Developer Apps migration.
 *
 * @param {Object} edgeApp - Developer Apps from Apigee Edge.
 * @param {Array} xDeveloperApps - List of Developer Apps names in Apigee X.
 * @param {String} developerEmail - The email of the developer.
 * @param {Object} counter - Migration summary counter.
 */
async function handleMergeApp(edgeApp, xDeveloperApps, developerEmail, counter) {
  const xDeveloperAppNames = (xDeveloperApps && xDeveloperApps.length > 0)
    ? xDeveloperApps.map(app => app.name)
    : [];

  if (xDeveloperAppNames.includes(edgeApp.name)) {
    try {
      const edgeAppFormatted = await prepareAppPayload(edgeApp);
      const existingXApp = xDeveloperApps.find(app => app.name === edgeApp.name);
      const xDeveloperAppFormatted = await prepareAppPayload(existingXApp);
      const mergeResults = await mergeData(xDeveloperAppFormatted, edgeAppFormatted, true);

      let appSync = false;

      if (mergeResults.mergedData) {
        const mergedDeveloperApp = mergeResults.mergedData;
        const x_app = await updateDeveloperApp(Context.destinationClient, developerEmail, mergedDeveloperApp.name, JSON.stringify(mergedDeveloperApp));
        appSync = true;
        logDeviations('DeveloperApp', mergedDeveloperApp.name, mergeResults, x_app.createdAt);
      } else {
        appSync = true;
      }

      if (appSync) {
        let allCredentialsMigrated = true;
        const existingXKeys = (existingXApp.credentials || []).map(c => c.consumerKey);

        // Handle each set of credentials for the app
        for (const credential of edgeApp.credentials) {
          try {
            if (!existingXKeys.includes(credential.consumerKey)) {
              await processCredential(credential, edgeApp.name, developerEmail, true);
              existingXKeys.push(credential.consumerKey); // After create, update list
            } else {
              await processCredential(credential, edgeApp.name, developerEmail, false);
            }
          } catch (keyError) {
            handleMigrationError('DeveloperAppCredential', edgeApp.name, keyError, counter);
            counter.credentialErrors++;
            allCredentialsMigrated = false;
          }
        }

        if (allCredentialsMigrated) {
          counter.migrated++;
          logMigrationStatus('DeveloperApp', edgeApp.name, 'Migrated', '');
        } else {
          counter.failed++;
          logMigrationStatus('DeveloperApp', edgeApp.name, 'Failed', '');
        }
      }
    } catch (mergeError) {
      handleMigrationError('DeveloperApp', edgeApp.name, mergeError, counter);
    }
  } else {
    // Create new entity in X
    await handleCreateApp(edgeApp, xDeveloperApps, developerEmail, counter);
  }
}

/**
 * Handle the 'overwrite' execution model for Developer Apps migration.
 *
 * @param {Object} edgeApp - Developer Apps from Apigee Edge.
 * @param {Array} xDeveloperApps - List of Developer Apps names in Apigee X.
 * @param {String} developerEmail - The email of the developer.
 * @param {Object} counter - Migration summary counter.
 */
async function handleOverwriteApp(edgeApp, xDeveloperApps, developerEmail, counter) {
  const xDeveloperAppNames = (xDeveloperApps && xDeveloperApps.length > 0)
    ? xDeveloperApps.map(app => app.name)
    : [];

  if (xDeveloperAppNames.includes(edgeApp.name)) {
    try {
      await deleteApigeeXDeveloperAppById(Context.destinationClient, developerEmail, edgeApp.name);
    } catch (overwriteError) {
      handleMigrationError('DeveloperApp', edgeApp.name, overwriteError, counter);
    }
  }

  await handleCreateApp(edgeApp, [], developerEmail, counter);
}

/**
 * Prepare the payload for a developer app.
 *
 * @param {Object} app - Developer app data.
 * @returns {Object} - Prepared developer app payload.
 */
async function prepareAppPayload(app) {
  const appPayload = {
    name: app.name,
    apiProducts: app.apiProducts,
    attributes: app.attributes,
    appFamily: app.appFamily,
    callbackUrl: app.callbackUrl,
    scopes: app.scopes,
    status: app.status,
    keyExpiresIn: 1 // Expire Temp Key immediately after creation
  };

  return appPayload;
}

/**
 * Process migration for a developer app.
 *
 * @param {Object} app - The app to migrate.
 * @param {String} developerEmail - The email of the developer.
 * @param {Object} counter - Counter for tracking migration status.
 */
async function processMigration(app, developerEmail, counter) {
  try {
    const appPayload = await prepareAppPayload(app);
    const createdApp = await createDeveloperApp(Context.destinationClient, developerEmail, JSON.stringify(appPayload));

    if (createdApp) {
      const appName = createdApp.name;
      const developerID = createdApp.developerId;
      const deleteKey = createdApp.credentials[0].consumerKey;

      // Delete existing keys
      await deleteDeveloperAppKeys(Context.destinationClient, developerID, appName, deleteKey);

      let allCredentialsMigrated = true;

      // Handle each set of credentials for the app
      for (const credential of app.credentials) {
        try {
          await processCredential(credential, appName, developerID, true);
        } catch (keyError) {
          handleMigrationError('DeveloperAppCredential', appName, keyError, counter);
          counter.credentialErrors++;
          allCredentialsMigrated = false;
        }
      }

      if (allCredentialsMigrated) {
        counter.migrated++;
        logMigrationStatus('DeveloperApp', appName, 'Migrated', createdApp.createdAt);
      } else {
        counter.failed++;
        logMigrationStatus('DeveloperApp', appName, 'Failed', createdApp.createdAt);
      }
    }
  } catch (appError) {
    handleMigrationError('DeveloperApp', app.name, appError, counter);
  }
}

/**
 * Processes each credential for an app.
 *
 * @param {Object} credential - Credential to be processed.
 * @param {String} appName - Name of the application.
 * @param {String} developerID - ID of the developer.
 * @param {Boolean} isNew - Flag indicating if the credential is new.
 */
async function processCredential(credential, appName, developerID, isNew = true) {
  const apiProducts = credential.apiProducts.map(product => product.apiproduct);
  credential.apiProducts = apiProducts;

  if (credential.expiresAt !== -1) {
    const expiryInSeconds = Math.floor(credential.expiresAt / 1000) - Math.floor(Date.now() / 1000);
    credential.expiresInSeconds = expiryInSeconds;
    delete credential.expiresAt;
  }

  try {
    if (isNew) {
      // Create new App credentials
      await createDeveloperAppKeys(Context.destinationClient, developerID, appName, JSON.stringify(credential));
    }
    // Update App credentials to attach API Products
    await updateDeveloperAppKeys(Context.destinationClient, developerID, appName, credential.consumerKey, JSON.stringify(credential));
  } catch (error) {
    throw error; // Re-throw the error to parse as keyError.
  }
}

// Export the migrateDeveloperApps function as default
export default migrateDeveloperApps;