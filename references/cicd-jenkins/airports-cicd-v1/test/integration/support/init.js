/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* eslint-disable no-invalid-this */ // See usage in apickli Documentation
/* eslint-disable new-cap */
"use strict";

const apickliModule = require("apickli");
const { Before } = require("cucumber");

Before(function () {
  const host = process.env.TEST_HOST || "org-env.apigee.net";
  const basePath = process.env.TEST_BASE_PATH || "/airports-cicd/v1";
  this.apickli = new apickliModule.Apickli("https", `${host}${basePath}`);
  this.apickli.addRequestHeader("Cache-Control", "no-cache");
});
