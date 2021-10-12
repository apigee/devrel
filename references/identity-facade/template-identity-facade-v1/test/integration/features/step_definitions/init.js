/**
  Copyright 2020 Google LLC

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

const clientId = process.env.TEST_APP_CONSUMER_KEY
const clientSecret = process.env.TEST_APP_CONSUMER_SECRET
// PKCE code challenge method is set to 'S256'
const codeVerifier = process.env.TEST_APP_PKCE_CODE_VERIFIER
const codeChallenge = process.env.TEST_APP_PKCE_CODE_CHALLENGE
const username = 'johndoe'
const password = 'dummy-password'
const basePath = '/v1/oauth20'
const pkceQueryParams = '&code_challenge='+codeChallenge+'&code_challenge_method=S256'

Before(function() {
  this.apickli = new apickli.Apickli('https',
    process.env.TEST_HOST + basePath)
  this.apickli.scenarioVariables.clientId = clientId
  this.apickli.scenarioVariables.clientSecret = clientSecret
  this.apickli.scenarioVariables.username = username
  this.apickli.scenarioVariables.password = password
  this.apickli.scenarioVariables.codeVerifier = codeVerifier
  this.apickli.scenarioVariables.codeChallenge = codeChallenge
  this.apickli.scenarioVariables.pkceQueryParams = pkceQueryParams
})

setDefaultTimeout(60 * 1000)
