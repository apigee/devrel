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

import { fileURLToPath, pathToFileURL } from 'url';
import fs from 'fs';
import path from 'path';
import Context from '../utils/context.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Get a list of modules that support migrating content from the configured source
 * and destination gateways.
 *
 * @returns {array<{name: string,isSupported: () => bool,actions: () => array<{name: string, execute: ()}>}
 */
async function getSupportedModules() {
  const modulesDir = path.resolve(__dirname);
  const modules = [];

  for (let file of fs.readdirSync(modulesDir)) {
    if (fs.statSync(path.join(modulesDir, file)).isDirectory() == false) {
      continue;
    }

    const moduleFile = `${modulesDir}/${file}/module.js`;

    if (!fs.existsSync(moduleFile)) {
      continue;
    }

    const { default: module } = await import(pathToFileURL(moduleFile));

    if (module?.isSupported(Context.sourceGatewayId, Context.destinationGatewayId) && module.name && module.actions) {
      modules.push(module);
    }
  }

  return modules;
}

export default getSupportedModules;