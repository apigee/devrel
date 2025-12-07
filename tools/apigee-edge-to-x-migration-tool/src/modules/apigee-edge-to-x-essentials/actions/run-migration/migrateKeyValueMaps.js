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
import {
  getApigeeEdgeEnvKeyValueMaps,
  getApigeeEdgeEnvKeyValueMapsByMap,
  getApigeeEdgeEnvKVMEntry,
  getApigeeEdgeEnvKVMKeys,
  getApigeeEdgeOrgKeyValueMaps,
  getApigeeEdgeOrgKeyValueMapsByMap,
  getApigeeEdgeOrgKVMEntry,
  getApigeeEdgeOrgKVMKeys
} from "../../../../gateway-clients/apigee-edge/keyValueMaps/index.js";
import {
  getApigeeXEnvKeyValueMaps,
  getApigeeXEnvKeyValueMapsByMap,
  getApigeeXEnvKVMEntry,
  getApigeeXEnvKVMKeys,
  getApigeeXOrgKeyValueMaps,
  getApigeeXOrgKeyValueMapsByMap,
  getApigeeXOrgKVMEntry,
  getApigeeXOrgKVMKeys,
  createApigeeXEnvKeyValueMaps,
  createApigeeXEnvKVMEntries,
  createApigeeXOrgKeyValueMaps,
  createApigeeXOrgKVMEntries,
  deleteApigeeXOrgKeyValueMap,
  deleteApigeeXEnvKeyValueMap
} from "../../../../gateway-clients/apigee-x/keyValueMaps/index.js";
import {
  logMigrationStatus,
  handleMigrationError,
  markAsDuplicate
} from "./migrationLogHelper.js";

/**
 * Migrate key-value maps from Apigee Edge to Apigee X.
 *
 * @param {Object} options - Options for migration, including executionModel.
 */
async function migrateKeyValueMaps(options) {
  try {
    // Handle org-scope migrations
    const orgKVMCounter = {
      entityType: 'KeyValueMap',
      scope: 'organization',
      edgeMapsInScope: 0,
      migrated: 0,
      duplicates: 0,
      skipped: 0,
      failed: 0,
      totalEntries: 0
    };
    const edgeOrgKVMs = await getApigeeEdgeOrgKeyValueMaps(Context.sourceClient);
    const xOrgKVMs = await getApigeeXOrgKeyValueMaps(Context.destinationClient);

    const edgeOrgKVMNames = (Array.isArray(edgeOrgKVMs) && edgeOrgKVMs.length > 0) ? edgeOrgKVMs : [];
    orgKVMCounter.edgeMapsInScope = edgeOrgKVMNames.length;
    const xOrgKVMNames = (Array.isArray(xOrgKVMs) && xOrgKVMs.length > 0) ? xOrgKVMs : [];

    await migrateKVMs(edgeOrgKVMNames, xOrgKVMNames, 'organization', '', '', orgKVMCounter, options.executionModel);

    const envResults = [];
    const environmentMap = JSON.parse(process.env?.apigee_environment_map ?? '{}');
    for (const [sourceEnvironment, targetEnvironment] of Object.entries(environmentMap)) {
      // Handle environment-scope migrations
      const envKVMCounter = {
        entityType: 'KeyValueMap',
        scope: 'environment',
        edgeEnvironment: sourceEnvironment,
        xEnvironment: targetEnvironment,
        edgeMapsInScope: 0,
        migrated: 0,
        duplicates: 0,
        skipped: 0,
        failed: 0,
        totalEntries: 0
      };

      const edgeEnvKVMs = await getApigeeEdgeEnvKeyValueMaps(Context.sourceClient, sourceEnvironment);
      const xEnvKVMs = await getApigeeXEnvKeyValueMaps(Context.destinationClient, targetEnvironment);

      const edgeEnvKVMNames = (Array.isArray(edgeEnvKVMs) && edgeEnvKVMs.length > 0) ? edgeEnvKVMs : [];
      envKVMCounter.edgeMapsInScope = edgeEnvKVMNames.length;
      const xEnvKVMNames = (Array.isArray(xEnvKVMs) && xEnvKVMs.length > 0) ? xEnvKVMs : [];

      await migrateKVMs(edgeEnvKVMNames, xEnvKVMNames, 'environment', sourceEnvironment, targetEnvironment, envKVMCounter, options.executionModel);
      envResults.push({ ...envKVMCounter });
    }

    // Counter Summary of both Org and Env Level
    console.log(orgKVMCounter);
    console.log(envResults);

  } catch (error) {
    console.error("Error migrating KeyValueMaps:", error);
  }
}

/**
 * Migrate key-value maps based on the execution model.
 *
 * @param {Array} edgeKVMs - List of key-value maps in Apigee Edge.
 * @param {Array} xKVMs - List of key-value maps in Apigee X.
 * @param {String} scope - Migration scope ('organization' or environment name).
 * @param {String} sourceEnvironment - Source Environment if scope is environment.
 * @param {String} targetEnvironment - Target Environment if scope is environment.
 * @param {String} executionModel - The execution model ('create', 'merge', 'overwrite').
 */
async function migrateKVMs(edgeKVMs, xKVMs, scope, sourceEnvironment, targetEnvironment, counter, executionModel) {
  switch (executionModel) {
    case 'create':
      await handleCreateKVMs(edgeKVMs, xKVMs, scope, sourceEnvironment, targetEnvironment, counter);
      break;
    case 'merge':
      await handleMergeKVMs(edgeKVMs, xKVMs, scope, sourceEnvironment, targetEnvironment, counter);
      break;
    case 'overwrite':
      await handleOverwriteKVMs(edgeKVMs, xKVMs, scope, sourceEnvironment, targetEnvironment, counter);
      break;
    default:
      console.error("Invalid execution model specified.");
  }
}

/**
 * Handle the 'create' execution model for KVM migration.
 */
async function handleCreateKVMs(edgeKVMs, xKVMs, scope, sourceEnvironment, targetEnvironment, counter) {
  for (const kvm of edgeKVMs) {
    try {
      // In Apigee X, KVM is encrypted by default.
      const KeyValueMap = {
        name: kvm,
        encrypted: true
      };

      let kvmState = '';

      if (xKVMs.includes(kvm)) {
        kvmState = 'duplicate';
        counter.duplicates++;
        logMigrationStatus('KeyValueMap', kvm, 'Duplicate', '');
        continue;
      }

      let isEncrypted, kvmEntries, entryCounter;
      switch (scope) {
        case 'organization':
          const orgKVMData = await getApigeeEdgeOrgKeyValueMapsByMap(Context.sourceClient, kvm);
          isEncrypted = orgKVMData.encrypted === true;
          kvmEntries = orgKVMData.entry || [];
          if (isEncrypted) {
            console.log(`Skipping migration of Encrypted KVM from ${scope}: ${kvm}`);
            counter.skipped++;
            logMigrationStatus('KeyValueMap', kvm, 'Skipped', '');
            continue;
          }
          if (kvmState !== 'duplicate') {
            await createApigeeXOrgKeyValueMaps(Context.destinationClient, JSON.stringify(KeyValueMap));
          }
          // Proceed adding Entries
          entryCounter = await processKVMEntries(kvm, scope, '', '', kvmEntries, counter);

          counter.migrated++;
          logMigrationStatus('KeyValueMap', kvm, 'Migrated', '');
          break;
        case 'environment':
          const envKVMData = await getApigeeEdgeEnvKeyValueMapsByMap(Context.sourceClient, sourceEnvironment, kvm);
          isEncrypted = envKVMData.encrypted === true;
          kvmEntries = envKVMData.entry || [];
          if (isEncrypted) {
            console.log(`Skipping migration of Encrypted KVM from ${scope}: ${kvm}`);
            counter.skipped++;
            logMigrationStatus('KeyValueMap', kvm, 'Skipped', '');
            continue;
          }
          if (kvmState !== 'duplicate') {
            await createApigeeXEnvKeyValueMaps(Context.destinationClient, targetEnvironment, JSON.stringify(KeyValueMap));
          }
          // Proceed adding Entries
          entryCounter = await processKVMEntries(kvm, scope, sourceEnvironment, targetEnvironment, kvmEntries, counter);
          counter.migrated++;
          logMigrationStatus('KeyValueMap', kvm, 'Migrated', '');
          break;
        default:
          break;
      }

      if (entryCounter) {
        counter.totalEntries = (counter.totalEntries || 0) + entryCounter.totalEntries;
        counter.migratedEntries = (counter.migratedEntries || 0) + entryCounter.migrated;
        counter.failedEntries = (counter.failedEntries || 0) + entryCounter.failed;
      }
    } catch (error) {
      handleMigrationError('KeyValueMap', kvm, error, counter);
    }
  }
}

/**
 * Handle the 'merge' execution model for KVM migration.
 */
async function handleMergeKVMs(edgeKVMs, xKVMs, scope, sourceEnvironment, targetEnvironment, counter) {
  console.log("Synchronize KeyValue Maps is not available");
}

/**
 * Handle the 'overwrite' execution model for KVM migration.
 */
async function handleOverwriteKVMs(edgeKVMs, xKVMs, scope, sourceEnvironment, targetEnvironment, counter) {
  for (const kvm of edgeKVMs) {
    if (xKVMs.includes(kvm)) {
      try {
        switch (scope) {
          case 'organization':
            await deleteApigeeXOrgKeyValueMap(Context.destinationClient, kvm);
            break;
          case 'environment':
            await deleteApigeeXEnvKeyValueMap(Context.destinationClient, targetEnvironment, kvm);
            break;
          default:
            break;
        }
      } catch (overwriteError) {
        handleMigrationError('KeyValueMap', kvm, overwriteError, counter);
      }
    }
    await handleCreateKVMs([kvm], [], scope, sourceEnvironment, targetEnvironment, counter);
  }
}

/**
 * Processes and creates entries for key-value maps.
 * @param {Object} kvmName - The name of KVM to which entry is to be added.
 * @param {Object} kvmEntry - The KVM entry containing key-value information.
 * @param {string} scope - Scope of key value map 'organization' or 'environment'.
 * @param {string} environment - The environment where the map should be created.
 */
async function processKVMEntries(kvmName, scope, sourceEnvironment, targetEnvironment, kvmEntries, counter) {
  const orgEntryCounter = {
    entityType: 'KeyValueMapEntry',
    entityName: kvmName,
    scope: scope,
    totalEntries: 0,
    migrated: 0,
    duplicates: 0,
    skipped: 0,
    failed: 0
  };

  const envEntryCounter = {
    entityType: 'KeyValueMapEntry',
    entityName: kvmName,
    scope: scope,
    edgeEnvironment: sourceEnvironment,
    xEnvironment: targetEnvironment,
    totalEntries: 0,
    migrated: 0,
    duplicates: 0,
    skipped: 0,
    failed: 0
  };

  switch (scope) {
    case 'organization':
      for (const keyValuePair of kvmEntries) {
        orgEntryCounter.totalEntries++;
        try {
          await createApigeeXOrgKVMEntries(Context.destinationClient, kvmName, JSON.stringify(keyValuePair));
          orgEntryCounter.migrated++;
        } catch (entryError) {
          orgEntryCounter.failed++;
        }
      }
      return orgEntryCounter;
    case 'environment':
      for (const keyValuePair of kvmEntries) {
        envEntryCounter.totalEntries++;
        try {
          await createApigeeXEnvKVMEntries(Context.destinationClient, targetEnvironment, kvmName, JSON.stringify(keyValuePair));
          envEntryCounter.migrated++;
        } catch (entryError) {
          envEntryCounter.failed++;
        }
      }
      return envEntryCounter;
    default:
      return null;
  }
}

// Export the migrateKeyValueMaps function as default
export default migrateKeyValueMaps;