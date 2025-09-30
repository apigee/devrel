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
  getApigeeEdgeApiProducts
} from "../../../../gateway-clients/apigee-edge/api-products/index.js";
import {
  getApigeeXApiProducts,
  getApigeeXApiProductByName,
  createApigeeXApiProduct,
  updateApigeeXApiProduct
} from "../../../../gateway-clients/apigee-x/api-products/index.js";
import {
  logMigrationStatus,
  handleMigrationError,
  markAsDuplicate,
  logDeviations
} from "./migrationLogHelper.js";

/**
 * Migrate API products from Apigee Edge to Apigee X using the specified execution model.
 *
 * @param {Object} options - Options for migration, including executionModel.
 */
async function migrateApiProducts(options) {
  try {
    // Retrieve API products from Apigee Edge and Apigee X
    const edgeProducts = await getApigeeEdgeApiProducts(Context.sourceClient);
    const apiProductNames = await getApigeeXApiProducts(Context.destinationClient);

    // Extract product names from Apigee X
    const xProductNames = apiProductNames.apiProduct?.map(product => product.name) || [];

    // Initialize a counter for tracking migration summary
    const counter = {
      entityType: 'APIProduct',
      edgeTotal: edgeProducts.length,
      migrated: 0,
      duplicates: 0,
      skipped: 0,
      failed: 0
    };

    // Process each API product from Apigee Edge
    for (let apiProduct of edgeProducts) {
      await processApiProduct(apiProduct, xProductNames, options.executionModel, counter);
    }

    // Log the final migration summary
    console.log(counter);
  } catch (error) {
    console.error("Error migrating API products:", error);
  }
}

/**
 * Process an individual API product based on the execution model.
 *
 * @param {Object} apiProduct - API product from Apigee Edge.
 * @param {Array} xProductNames - List of API product names in Apigee X.
 * @param {String} executionModel - The execution model ('create', 'merge', 'overwrite').
 * @param {Object} counter - Migration summary counter.
 */
async function processApiProduct(apiProduct, xProductNames, executionModel, counter) {
  switch (executionModel) {
    case 'create':
      await handleCreateProduct(apiProduct, xProductNames, counter);
      break;
    case 'merge':
      await handleMergeProduct(apiProduct, xProductNames, counter);
      break;
    case 'overwrite':
      await handleOverwriteProduct(apiProduct, xProductNames, counter);
      break;
    default:
      console.error("Invalid execution model specified.");
  }
}

/**
 * Handle the 'create' execution model for API product migration.
 *
 * @param {Object} apiProduct - API product from Apigee Edge.
 * @param {Array} xProductNames - List of API product names in Apigee X.
 * @param {Object} counter - Migration summary counter.
 */
async function handleCreateProduct(apiProduct, xProductNames, counter) {
  if (!xProductNames.includes(apiProduct.name)) {
    try {
      const edgeProduct = await prepareProductPayload(apiProduct);
      const x_product = await createApigeeXApiProduct(Context.destinationClient, JSON.stringify(edgeProduct));
      counter.migrated++;
      logMigrationStatus('APIProduct', apiProduct.name, 'Migrated', x_product.createdAt);
    } catch (creationError) {
      handleMigrationError('APIProduct', apiProduct.name, creationError, counter);
    }
  } else {
    markAsDuplicate('APIProduct', apiProduct.name, counter);
  }
}

/**
 * Handle the 'merge' execution model for API product migration.
 *
 * @param {Object} apiProduct - API product from Apigee Edge.
 * @param {Array} xProductNames - List of API product names in Apigee X.
 * @param {Object} counter - Migration summary counter.
 */
async function handleMergeProduct(apiProduct, xProductNames, counter) {
  if (xProductNames.includes(apiProduct.name)) {
    try {
      const edgeProduct = await prepareProductPayload(apiProduct);
      const existingXProduct = await getApigeeXApiProductByName(Context.destinationClient, apiProduct.name);
      const xProductFormatted = {
        ...await prepareProductPayload(existingXProduct),
        environments: existingXProduct.environments
      };
      const mergeResults = await mergeData(xProductFormatted, edgeProduct, true);

      if (mergeResults.mergedData) {
        const mergedProduct = mergeResults.mergedData;
        const x_product = await updateApigeeXApiProduct(Context.destinationClient, mergedProduct.name, JSON.stringify(mergedProduct));
        counter.migrated++;
        logMigrationStatus('APIProduct', mergedProduct.name, 'Migrated', x_product.createdAt);
        logDeviations('APIProduct', mergedProduct.name, mergeResults, x_product.createdAt);
      } else {
        markAsDuplicate('APIProduct', apiProduct.name, counter);
      }
    } catch (mergeError) {
      handleMigrationError('APIProduct', apiProduct.name, mergeError, counter);
    }
  } else {
    // Create new entity in X if it does not exist
    await handleCreateProduct(apiProduct, xProductNames, counter);
  }
}

/**
 * Handle the 'overwrite' execution model for API product migration.
 *
 * @param {Object} apiProduct - API product from Apigee Edge.
 * @param {Array} xProductNames - List of API product names in Apigee X.
 * @param {Object} counter - Migration summary counter.
 */
async function handleOverwriteProduct(apiProduct, xProductNames, counter) {
  if (xProductNames.includes(apiProduct.name)) {
    try {
      const edgeProduct = await prepareProductPayload(apiProduct);
      const x_product = await updateApigeeXApiProduct(Context.destinationClient, edgeProduct.name, JSON.stringify(edgeProduct));
      counter.migrated++;
      logMigrationStatus('APIProduct', apiProduct.name, 'Migrated', x_product.createdAt);
    } catch (overwriteError) {
      handleMigrationError('APIProduct', apiProduct.name, overwriteError, counter);
    }
  } else {
    // Create new entity in X if it does not exist
    await handleCreateProduct(apiProduct, xProductNames, counter);
  }
}

/**
 * Prepare the payload for an API product.
 *
 * @param {Object} apiProduct - API product data.
 * @returns {Object} - Prepared API product payload.
 */
async function prepareProductPayload(apiProduct) {
  const environmentMap = JSON.parse(process.env?.apigee_environment_map ?? '{}');

  return {
    name: apiProduct.name || '',
    displayName: apiProduct.displayName || '',
    approvalType: apiProduct.approvalType || '',
    attributes: apiProduct.attributes || [],
    description: apiProduct.description || '',
    apiResources: apiProduct.apiResources || [],
    environments: (apiProduct.environments ?? []).map(environment => environmentMap[environment]),
    proxies: apiProduct.proxies || [],
    quota: apiProduct.quota || '',
    quotaInterval: apiProduct.quotaInterval || '',
    quotaTimeUnit: apiProduct.quotaTimeUnit || '',
    scopes: apiProduct.scopes || []
  };
}

// Export the migrateApiProducts function as default
export default migrateApiProducts;