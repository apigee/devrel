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

import errorHandler from "../../../../utils/errorHandler.js";
import Logger from "../../../../utils/logHandler.js";

/**
 * Log migration status for an Entity Type.
 *
 * @param {String} name - Name of the Entity Type.
 * @param {String} state - Migration state (e.g., 'Migrated', 'Failed').
 * @param {String} attemptedAt - Timestamp of the migration attempt.
 */
export function logMigrationStatus(entityType, name, state, attemptedAt) {
  Logger.getInstance().createStatusEntry({
    entityType: entityType,
    entityName: name,
    migrationState: state,
    migrationAttempted: attemptedAt ? epochToIso(Number(attemptedAt)) : new Date().toISOString(),
    cause: ''
  });
}
/**
 * Handle migration errors for an Entity Type.
 *
 * @param {String} name - Name of the Entity Type.
 * @param {Error} error - Error encountered during migration.
 * @param {Object} counter - Migration summary counter.
 */
export async function handleMigrationError(entityType, name, error, counter) {
  const { code, message } = await errorHandler(error);
  switch (Number(code)) {
    case 409:
      markAsDuplicate(entityType, name, counter)
      return code;
    default:
      counter.failed++;
      Logger.getInstance().createStatusEntry({
        entityType: entityType,
        entityName: name,
        migrationState: 'Failed',
        migrationAttempted: new Date().toISOString(),
        cause: `${entityType} Creation Error [${code}]: ${message}`
      });
      break;
  }
}
/**
 * Mark an Entity Type as a duplicate during migration.
 *
 * @param {String} name - Name of the Entity Type.
 * @param {Object} counter - Migration summary counter.
 */
export function markAsDuplicate(entityType, name, counter) {
  counter.duplicates++;
  Logger.getInstance().createStatusEntry({
    entityType: entityType,
    entityName: name,
    migrationState: 'Skipped',
    migrationAttempted: new Date().toISOString(),
    cause: `Duplicate`
  });
}
/**
 * Log deviations found during the merge process of an Entity Type.
 *
 * @param {String} name - Name of the Entity Type.
 * @param {Object} mergeResults - Results of the merge operation.
 * @param {String} attemptedAt - Timestamp of the migration attempt.
 */
export function logDeviations(entityType, name, mergeResults, attemptedAt) {
  Logger.getInstance().createDeviationsEntry({
    entityType: entityType,
    entityName: name,
    source_data: mergeResults.source,
    target_data: mergeResults.target,
    deviations: mergeResults.deviations,
    merged_data: mergeResults.mergedData,
    migrationAttempted: attemptedAt ? epochToIso(Number(attemptedAt)) : new Date().toISOString()
  });
}

export function epochToIso(epochTimestamp) {
  // Ensure the timestamp is a number
  if (typeof epochTimestamp !== 'number' || isNaN(epochTimestamp)) {
    throw new Error('Invalid epoch timestamp');
  }
  // Determine if the epoch timestamp is in seconds or milliseconds
  const isMilliseconds = epochTimestamp > 9999999999;

  // Convert the epoch timestamp to milliseconds if it's in seconds
  const timestampInMs = isMilliseconds ? epochTimestamp : epochTimestamp * 1000;

  // Create a new Date object using the timestamp in milliseconds
  const date = new Date(timestampInMs);

  // Convert the Date object to an ISO 8601 formatted string
  const isoString = date.toISOString();

  return isoString;
}
