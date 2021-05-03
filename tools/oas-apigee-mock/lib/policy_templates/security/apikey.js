/**
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

const builder = require('xmlbuilder')

module.exports = {
  apiKeyTemplate: apiKeyTemplate,
  apiKeyGenTemplate: apiKeyGenTemplate
}

/**
 * Generates XML for API Key Validation policy
 * @param  {object} options - Policy Options
 * @return {string}
 */
function apiKeyTemplate(options) {
  const aysnc = options.async || 'false'
  const continueOnError = options.continueOnError || 'false'
  const enabled = options.enabled || 'true'
  const name = options.name || 'va-verifyapikey'
  const apiKeyName = options.apiKeyName || 'apikey'

  let keyRef
  if (options.keyRef === 'header') {
    keyRef = 'request.header.' + apiKeyName
  } else {
    keyRef = 'request.queryparam.' + apiKeyName
  }

  const apiKey = builder.create('VerifyAPIKey')
  apiKey.att('async', aysnc)
  apiKey.att('continueOnError', continueOnError)
  apiKey.att('enabled', enabled)
  apiKey.att('name', name)

  apiKey.ele('Properties', {})
  apiKey.ele('APIKey', { ref: keyRef })

  const xmlString = apiKey.end({ pretty: true, indent: '  ', newline: '\n' })
  return xmlString
}

/**
 * Generates XML for API Key Validation policy
 * @param  {object} options
 * @param  {string} name
 * @return {string}
 */
function apiKeyGenTemplate(options, name) {
  const templateOptions = options
  templateOptions.name = name
  if (name === 'apiKeyHeader') {
    templateOptions.keyRef = 'request.header.apikey'
  }
  return apiKeyTemplate(templateOptions)
}
