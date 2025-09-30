#!/usr/bin/env node
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
import getSupportedModules from './src/modules/index.js';

const modules = await getSupportedModules();

if (modules.length == 0) {
  console.log('No tools are available for migrating between your configured source and destination gateway types.');
  process.exit();
}

const moduleId = await select({
  message: 'Choose a tool',
  choices: modules.map((module, idx) => ({
    name: module.name,
    value: idx
  }))
});

const actions = modules[moduleId].actions();

const actionId = await select({
  message: 'Action',
  choices: actions.map((action, idx) => ({
    name: action.name,
    value: idx
  }))
});

await actions[actionId].execute();
