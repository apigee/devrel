/**
  Copyright 2021 Google LLC

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

/* eslint-disable no-invalid-this */ // See usage in apickli Documentation
/* eslint-disable new-cap */
"use strict";

const apickli = require('apickli')
const {
  Before,
  setDefaultTimeout
} = require('cucumber')

const basePath = '/threats/v1'
const depth = 5
const length = 5
const height = 5
const width = 5

Before(function() {
  this.apickli = new apickli.Apickli('https', process.env.TEST_HOST + basePath)
  this.apickli.scenarioVariables.depth = depth
  this.apickli.scenarioVariables.length = length
  this.apickli.scenarioVariables.width = width
  this.apickli.scenarioVariables.height = height
  this.apickli.addRequestHeader("Cache-Control", "no-cache");
})

setDefaultTimeout(60 * 1000)