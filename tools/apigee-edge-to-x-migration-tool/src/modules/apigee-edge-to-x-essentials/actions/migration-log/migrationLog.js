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

// Import necessary modules
import Logger from "../../../../utils/logHandler.js";
import { select } from '@inquirer/prompts';

// Define log options for navigation
const logOptions = [
  { name: 'Status', option: 'viewMigrationStatus', description: 'Select to view migration status of one/all entities.' },
  { name: 'Summary', option: 'viewMigrationSummary', description: 'Select to view the migration status summary of one/all entities.' },
  { name: 'Delta', option: 'viewDeviations', description: 'Select to view the delta information identified by comparing source and target entity.' },
  { name: 'Logs', option: 'viewLogs', description: 'Select to view transaction logs.' },
  { name: 'Exit', option: 'Exit', description: 'Exit Tool' }
];

// Define entity types for selection
const entityTypes = [
  { name: 'Back', type: 'Back', description: 'Navigate to previous menu.' },
  { name: 'All Entities', type: null, description: 'All entity types.' },
  { name: 'API Proxies', type: 'APIProxy', description: 'API proxies entity type.' },
  { name: 'API Products', type: 'APIProduct', description: 'API products entity type.' },
  { name: 'Developer Apps', type: 'DeveloperApp', description: 'Developer apps entity type.' },
  { name: 'Developers', type: 'Developer', description: 'Developer entity type.' },
  { name: 'KeyValueMaps', type: 'KeyValueMap', description: 'Key value maps entity type.' },
  { name: 'Resource Files', type: 'ResourceFiles', description: 'Resource files entity type.' },
  { name: 'Shared Flows', type: 'SharedFlow', description: 'Shared flows entity type.' },
  { name: 'Exit', type: 'Exit', description: 'Exit Tool' }
];

// Define migration status options
const migrationStatus = [
  { name: 'Back', state: 'Back', description: 'Navigate to previous menu.' },
  { name: 'All', state: null, description: 'All migration states.' },
  { name: 'Migrated', state: 'Migrated', description: 'Entities that have been migrated.' },
  { name: 'Skipped', state: 'Skipped', description: 'Entities that have been skipped.' },
  { name: 'Error', state: 'Failed', description: 'Entities with errors.' },
  { name: 'Exit', state: 'Exit', description: 'Exit Tool' }
];

// Define log levels for viewing
const logLevel = [
  { name: 'Back', level: 'Back', description: 'Navigate to previous menu.' },
  { name: 'All', level: null, description: 'All log levels.' },
  { name: 'Log', level: 'log', description: 'Standard log messages.' },
  { name: 'Warning', level: 'warning', description: 'Warning messages.' },
  { name: 'Error', level: 'error', description: 'Error messages.' },
  { name: 'Exit', level: 'Exit', description: 'Exit Tool' }
];

/**
 * Main function to navigate through migration logs using a menu system.
 */
async function migrationLog() {
  let continueNavigation = true;
  const menuStack = [];

  // Function to navigate menu choices
  const navigateMenu = async (choices, message) => {
    const selectedOption = await select({
      name: 'menuOption',
      message,
      choices: choices.map(choice => ({
        name: choice.name,
        value: choice.option || choice.type || choice.state || choice.level,
        description: choice.description
      })),
    });

    // Handle menu navigation and exit conditions
    if (selectedOption === 'Exit') {
      continueNavigation = false;
      menuStack.length = 0; // Clear stack for a fresh start
    } else if (selectedOption === 'Back') {
      if (menuStack.length > 0) {
        menuStack.pop(); // Go back to the previous menu
      }
    } else {
      if (menuStack[menuStack.length - 1] !== selectedOption) {
        menuStack.push(selectedOption);
      }
    }

    return selectedOption;
  };

  while (continueNavigation) {
    const currentMenu = menuStack[menuStack.length - 1] || 'mainMenu';

    let selectedLogType, selectedEntityType, selectedMigrationState, selectedLogLevel;

    // Switch between different menus and actions based on the current menu
    switch (currentMenu) {
      case 'mainMenu':
        selectedLogType = await navigateMenu(logOptions, 'Choose Log Type');
        if (selectedLogType === 'Back' || selectedLogType === 'Exit') {
          continue;
        } else if (selectedLogType === 'viewMigrationStatus' || selectedLogType === 'viewMigrationSummary' || selectedLogType === 'viewDeviations' || selectedLogType === 'viewLogs') {
          if (!menuStack.includes(selectedLogType)) {
            menuStack.push(selectedLogType);
          }
          console.log(menuStack);
        }
        break;

      case 'viewMigrationStatus':
        selectedEntityType = await navigateMenu(entityTypes, 'Choose Entity');
        if (selectedEntityType === 'Back' || selectedEntityType === 'Exit') {
          continue;
        }

        selectedMigrationState = await navigateMenu(migrationStatus, 'Choose Migration State');
        if (selectedMigrationState === 'Back' || selectedMigrationState === 'Exit') {
          continue;
        }

        await Logger.getInstance().viewMigrationStatus(selectedEntityType, selectedMigrationState);
        break;

      case 'viewMigrationSummary':
        selectedEntityType = await navigateMenu(entityTypes, 'Choose Entity');
        if (selectedEntityType === 'Back' || selectedEntityType === 'Exit') {
          continue;
        }

        await Logger.getInstance().viewMigrationSummary(selectedEntityType);
        break;

      case 'viewDeviations':
        selectedEntityType = await navigateMenu(entityTypes, 'Choose Entity');
        if (selectedEntityType === 'Back' || selectedEntityType === 'Exit') {
          continue;
        }

        await Logger.getInstance().viewDeviations(selectedEntityType);
        break;

      case 'viewLogs':
        selectedLogLevel = await navigateMenu(logLevel, 'Choose Log Level');
        if (selectedLogLevel === 'Back' || selectedLogLevel === 'Exit') {
          continue;
        }

        await Logger.getInstance().viewLogs(selectedLogLevel);
        break;

      default:
        break;
    }
  }
}

// Export the migrationLog function as default
export default migrationLog;