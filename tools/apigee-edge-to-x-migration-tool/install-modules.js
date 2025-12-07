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

import path from 'path'
import fs from 'fs'
import child_process from 'child_process'
import dotenv from 'dotenv';

dotenv.config();

if ((process.env.install_modules ?? null) !== "1") {
  process.exit();
}

const modulesPath = `${process.cwd()}/src/modules`;

for (let moduleName of fs.readdirSync(modulesPath)) {
  const modulePath = path.join(modulesPath, moduleName);
  const packageJsonPath = path.join(modulePath, 'package.json');

  if (!fs.statSync(modulePath).isDirectory() || !fs.existsSync(packageJsonPath)) {
    continue;
  }

  console.log(`Installing module ${moduleName}`);
  child_process.execSync('npm install', { cwd: modulePath, env: process.env, stdio: 'inherit' })
}
