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

import fs from 'fs';

/**
 * 
 * @param {string} moduleName 
 * @returns {string} 
 */
function getDataDirectory(moduleName) {
  if (typeof moduleName !== 'string' || !moduleName.match(/^[-_A-Za-z0-9]{1,32}$/g)) {
    throw new Error(`Invalid module name "${moduleName}" when requesting data directory.`);
  }

  const migrationDataDirectory = `${process.cwd()}/data/${moduleName}`;

  if (!fs.existsSync(migrationDataDirectory)) {
    fs.mkdirSync(migrationDataDirectory, {
      recursive: true
    });
  }

  return migrationDataDirectory;
}

export default getDataDirectory;