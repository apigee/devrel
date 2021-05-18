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
  assignMessageTemplate: assignMessageTemplate,
  assignMessageGenTemplate: assignMessageGenTemplate
}

/**
 * Generates XML for Assign Message policy
 * @param  {object} options - Policy Options
 * @return {string}
 */
function assignMessageTemplate(options) {

  const ignoreUnresolvedVariables = options.ignoreUnresolvedVariables || 'false'
  const name = options.name || 'am-' + random.randomText()
  const displayName = options.displayName || name
  const content = options.payload || ''
  const statusCode = options.statusCode || ''
  const reasonPhrase = options.reasonPhrase || ''

  const assignMessage = builder.create('AssignMessage')
  assignMessage.att('name', name)
  assignMessage.ele('DisplayName', {}, displayName)
  assignMessage.ele('IgnoreUnresolvedVariables', {}, ignoreUnresolvedVariables)
  assignMessage.ele('Set')
    .ele('Payload').att('contentType', 'application/json')
    .txt(content)
    .up()
    .ele('StatusCode').txt(statusCode)
    .up()
    .ele('ReasonPhrase').txt(reasonPhrase)

  const xmlString = assignMessage.end({ pretty: true, indent: '  ', newline: '\n' })
  return xmlString
}

/**
 * Generates XML for Assign Message policy
 * @param  {object} options
 * @param  {string} name
 * @return {string}
 */
function assignMessageGenTemplate(options, name) {
  const templateOptions = options
  templateOptions.name = name

  return assignMessageTemplate(templateOptions)
}
