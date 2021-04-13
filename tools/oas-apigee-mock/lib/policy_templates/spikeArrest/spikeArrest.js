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
const random = require('../../util/random.js')

module.exports = {
  spikeArrestTemplate: spikeArrestTemplate,
  spikeArrestGenTemplate: spikeArrestGenTemplate
}

/**
 * Generates XML for Spike Arrest policy
 * @param  {object} options - Policy Options
 * @return {string}
 */
function spikeArrestTemplate(options) {
  const aysnc = options.async || 'false'
  const continueOnError = options.continueOnError || 'false'
  const enabled = options.enabled || 'true'
  const name = options.name || 'SpikeArrest-' + random.randomText()
  const displayName = options.displayName || name
  const identifierRef = options.identifierRef || 'request.header.some-header-name'
  const messageWeightRef = options.intervalRef || 'request.header.weight'
  const rate = options.rate || '30ps'

  const spike = builder.create('SpikeArrest')
  spike.att('async', aysnc)
  spike.att('continueOnError', continueOnError)
  spike.att('enabled', enabled)
  spike.att('name', name)

  spike.ele('DisplayName', {}, displayName)
  spike.ele('Properties', {})
  spike.ele('Identifier', { ref: identifierRef })
  spike.ele('MessageWeight', { ref: messageWeightRef })
  spike.ele('Rate', {}, rate)
  const xmlString = spike.end({ pretty: true, indent: '  ', newline: '\n' })
  return xmlString
}

/**
 * Generates XML for Spike Arrest policy
 * @param  {object} options
 * @param  {string} name
 * @return {string}
 */
function spikeArrestGenTemplate(options, name) {
  const templateOptions = options
  templateOptions.name = name
  if (options.timeUnit === 'minute') {
    templateOptions.rate = options.allow + 'pm'
  } else {
    templateOptions.rate = options.allow + 'ps'
  }
  return spikeArrestTemplate(templateOptions)
}
