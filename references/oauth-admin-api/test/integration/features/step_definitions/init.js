/**
  Copyright 2022 Google LLC

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      https://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/
const apickli = require('apickli')
const {
  Before,
  setDefaultTimeout
} = require('@cucumber/cucumber')

const hostname = process.env.TEST_HOST
const clientId = process.env.TEST_CLIENT_ID
const clientSecret = process.env.TEST_CLIENT_SECRET
const basePath = process.env.TEST_BASE_PATH || "/oauth-admin/v1";

Before(function() {
  this.apickli = new apickli.Apickli('https', hostname + basePath)
  this.apickli.scenarioVariables.clientId = clientId
  this.apickli.scenarioVariables.clientSecret = clientSecret
})

setDefaultTimeout(60 * 1000)
