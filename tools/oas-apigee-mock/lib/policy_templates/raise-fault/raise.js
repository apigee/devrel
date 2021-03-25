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

var builder = require('xmlbuilder')

module.exports = {
  raiseFaultTemplate: raiseFaultTemplate,
  raiseFaultGenTemplate: raiseFaultGenTemplate
}

function raiseFaultTemplate (options) {
  var name = options.name
  var displayName = options.displayName || name
  var statusCode = options.statusCode || '500'
  var reasonPhrase = options.reasonPhrase || 'Ooops'
  var msg = builder.create('RaiseFault')
  msg.att('name', displayName)
  msg.ele('DisplayName', {}, displayName)
  msg.ele('Properties', {})
  var FaultResponse = msg.ele('FaultResponse').ele('Set')
  FaultResponse.ele('Headers')
  FaultResponse.ele('Payload', { contentType: 'text/plain' })
  FaultResponse.ele('StatusCode', statusCode)
  FaultResponse.ele('ReasonPhrase', reasonPhrase)
  var xmlString = msg.end({ pretty: true, indent: '  ', newline: '\n' })
  return xmlString
}

function raiseFaultGenTemplate (options, name) {
  var templateOptions = options
  templateOptions.count = options.allow
  templateOptions.name = name

  return raiseFaultTemplate(templateOptions)
}
