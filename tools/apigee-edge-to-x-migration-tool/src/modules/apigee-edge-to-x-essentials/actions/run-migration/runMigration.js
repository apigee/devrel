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

import { select } from '@inquirer/prompts';

// List of migration types, now includes Back and Home options
const migrationTypes = [
  {
    name: 'API Proxies',
    migrationHandler: `./migrateApiProxies.js`,
    description: 'Select to migrate API Proxies.',
  },
  {
    name: 'API Products',
    migrationHandler: `./migrateApiProducts.js`,
    description: 'Select to migrate API Products.',
  },
  {
    name: 'Developer Apps',
    migrationHandler: `./migrateDeveloperApps.js`,
    description: 'Select to migrate Developer Apps.',
  },
  {
    name: 'Developers',
    migrationHandler: `./migrateDevelopers.js`,
    description: 'Select to migrate Developers.',
  },
  {
    name: 'KeyValueMaps',
    migrationHandler: `./migrateKeyValueMaps.js`,
    description: 'Select to migrate Unencrypted Key Value Maps.',
  },
  {
    name: 'Resource Files',
    migrationHandler: `./migrateResourceFiles.js`,
    description: 'Select to migrate Environment Level Resource files.',
  },
  {
    name: 'Shared Flows',
    migrationHandler: `./migrateSharedFlows.js`,
    description: 'Select to migrate Shared Flows.',
  },
  { name: 'Exit', value: 'Exit', description: 'Exit Tool' }
];

async function runMigration() {
  let continueNavigation = true;
  const menuStack = [];

  const navigateMenu = async (choices, message) => {
    const selectedOption = await select({
      name: 'menuOption',
      message,
      choices: choices.map(choice => ({
        name: choice.name,
        value: choice.migrationHandler || choice.value,
        description: choice.description,
      })),
    });

    if (selectedOption === 'Exit') {
      // console.log("Exit Tool...");
      continueNavigation = false;
      menuStack.length = 0; // Clear stack for a fresh start
    } else if (selectedOption === 'Back') {
      if (menuStack.length > 0) {
        menuStack.pop(); // Go back to the previous menu
      } else {
        // If at main menu and back is selected, end navigation
        continueNavigation = false;
      }
    } else {
      menuStack.push(selectedOption); // Add to stack if navigating deeper
    }

    return selectedOption;
  };

  while (continueNavigation) {
    const currentMenu = menuStack[menuStack.length - 1] || 'mainMenu';

    switch (currentMenu) {
      case 'mainMenu':
        const selectedMigration = await navigateMenu(migrationTypes, 'Choose what to migrate');

        if (selectedMigration === 'Back' || selectedMigration === 'Exit') {
          continue;
        }

        menuStack.push(selectedMigration); // Push the chosen migration for context in the next menu
        break;

      default:
        const nonSyncTypes = [
          './migrateApiProxies.js',
          './migrateSharedFlows.js',
          './migrateKeyValueMaps.js',
          './migrateResourceFiles.js'
        ];

        const executionModelOptions = [
          {
            name: 'Migrate',
            value: 'create',
            description: `Creates an entity if it doesn't exist. Skips if exists`
          },
          {
            name: 'Overwrite',
            value: 'overwrite',
            description: `Overwrites matching entities using data from Apigee Edge. Any changes done to same entity in Apigee X will be overwritten. Choose with caution.`
          },
          { name: 'Back', value: 'Back', description: 'Navigate to previous menu.' },
          { name: 'Exit', value: 'Exit', description: 'Exit Tool' }
        ];

        if (!nonSyncTypes.includes(currentMenu)) {
          executionModelOptions.splice(1, 0, {
            name: 'Synchronize',
            value: 'merge',
            description: `Compares Entity data between Edge and X. Synchronizes net new values from Edge to X. Any changed values in Apigee X will be left intact.`
          });
        }

        const executionModel = await navigateMenu(executionModelOptions, 'Select the execution model');

        if (executionModel === 'Back') {
          menuStack.pop();
          continue;
        } else if (executionModel === 'Exit') {
          // console.log("Exit Tool...");
          continueNavigation = false;
          break;
        }

        const { default: migrationHandler } = await import(currentMenu);
        migrationHandler({ executionModel });

        continueNavigation = false;
        break;
    }
  }
}

export default runMigration;