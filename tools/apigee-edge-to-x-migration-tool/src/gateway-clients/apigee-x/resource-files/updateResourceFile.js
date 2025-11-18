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

import ApigeeXClient from "../ApigeeXClient.js";
import { promises as fs } from 'fs';

/**
 * 
 * @param {ApigeeXClient} apigeeXClient 
 * @param {string} environment
 * @param {string} type
 * @param {string} name
 * @param {*} fileData 
 * @returns {Promise<*>}
 */
export default async function updateApigeeXResourceFile(apigeeXClient, environment, type, name, filePath) {
  const fileData = await fs.readFile(filePath).catch(err => {
    console.error(`Failed to fetch resourceFile bundle for ${name} type ${type}: ${err.message}`);
  });
  return apigeeXClient.put(`/environments/${environment}/resourcefiles/${type}/${name}`, fileData);
}
