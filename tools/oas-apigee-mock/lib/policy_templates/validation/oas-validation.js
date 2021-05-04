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
  oasValidationTemplate: oasValidationTemplate
}

/**
 * Generates XML for OAS Validation policy
 * @param  {object} options - Policy Options
 * @return {string}
 */
function oasValidationTemplate(options) {

  const name = options.name || 'oas-' + random.randomText()
  const displayName = options.displayName || name

  const oasValidation = builder.create('OASValidation')
  oasValidation.att('name', name)
  oasValidation.ele('DisplayName', {}, displayName)
  oasValidation.ele('Source', {}, "request")
  oasValidation.ele('OASResource', {}, "oas://" + options.resourceName)
  oasValidation.ele('Options')
    .ele('ValidateMessageBody')
    .txt("true")
    .up()
    .ele('AllowUnspecifiedParameters')
    .ele('Header')
    .txt("true")
    .up()
    .ele('Query')
    .txt("false")
    .up()
    .ele('Cookie')
    .txt("false")

  const xmlString = oasValidation.end({ pretty: true, indent: '  ', newline: '\n' })
  return xmlString
}
