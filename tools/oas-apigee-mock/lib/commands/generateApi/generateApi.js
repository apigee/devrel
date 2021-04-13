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

const parser = require('swagger-parser')
const generateSkeleton = require('./generateSkeleton.js')
const generateProxy = require('./generateProxy.js')
const generateProxyEndPoint = require('./generateProxyEndPoint.js')
const async = require('async')
const path = require('path')

module.exports = {
  generateApi: generateApi
}

function generateApi(apiProxy, options, cb) {
  console.log("generateApi")

  let destination = options.destination || path.join(__dirname, '../../../api_bundles')
  if (destination.substr(-1) === '/') {
    destination = destination.substr(0, destination.length - 1)
  }

  parser.parse(options.source, function (err, api, metadata) {
    if (!err) {
      console.log('Source specification is via: %s %s', (api.openapi ? 'OAS' : 'Swagger'), (api.openapi ? api.openapi : api.swagger))
      console.log('API name: %s, Version: %s', api.info.title, api.info.version)
      console.log('Destination: %s', destination)

      generateSkeleton(apiProxy, options, function (err, reply) {
        if (err) return cb(err)
        async.parallel([
          function (callback) {
            generateProxy(apiProxy, options, api, function (err, reply) {
              if (err) return callback(err)
              callback(null, 'genProxy')
            })
          },
          function (callback) {
            generateProxyEndPoint(apiProxy, options, api, function (err, reply) {
              if (err) return callback(err)
              callback(null, 'genProxyEndPoint')
            })
          }
        ]
        )
      })
    } else {
      return cb(err, { error: 'openapi parsing failed..' })
    }
  })
}
