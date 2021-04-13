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
const fs = require('fs')
const path = require('path')

module.exports = function generateProxy (apiProxy, options, api, cb) {
  let destination = options.destination || path.join(__dirname, '../../../api_bundles')
  if (destination.substr(-1) === '/') {
    destination = destination.substr(0, destination.length - 1)
  }
  let rootDirectory = destination + '/' + apiProxy + '/apiproxy'
  let root = builder.create('APIProxy')
  root.att('revison', 1)
  root.att('name', apiProxy)
  root.ele('CreatedAt', {}, Math.floor(Date.now() / 1000))
  root.ele('Description', {}, api.info.title)
  let proxyEndPoints = root.ele('ProxyEndpoints', {})
  proxyEndPoints.ele('ProxyEndpoint', {}, 'default')
  let targetEndPoints = root.ele('TargetEndpoints', {})
  targetEndPoints.ele('TargetEndpoint', {}, 'default')
  let xmlString = root.end({ pretty: true, indent: '  ', newline: '\n' })
  fs.writeFile(rootDirectory + '/' + apiProxy + '.xml', xmlString, function (err) {
    if (err) {
      return cb(err, {})
    }
    cb(null, {})
  })
}
