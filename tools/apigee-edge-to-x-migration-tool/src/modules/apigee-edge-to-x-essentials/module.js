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

import runMigration from './actions/run-migration/runMigration.js';
import migrationLog from './actions/migration-log/migrationLog.js';

/**
 * Module for migrating essential data from Apigee Edge to Apigee X, including:
 * API Proxies, API Proxy Deployments, Shared Flows, Shared Flow Deployments, Developers,
 * Developer Apps, API Products, and Resources
 */
const module = {
    name: 'Apigee Edge to X',

    isSupported: (sourceGatewayId, destinationGatewayId) => {
        return sourceGatewayId === 'apigee_edge' && destinationGatewayId === 'apigee_x';
    },

    actions: () => {
        return [
            {
                name: 'Migrate',
                execute: runMigration
            },
            {
                name: 'View Logs',
                execute: migrationLog
            }
        ]
    }
}

export default module;