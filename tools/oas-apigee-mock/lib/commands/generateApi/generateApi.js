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
const generateProxyEndPoint = require('./generateProxyEndPoint.js')
const path = require('path')

module.exports = {
  generateApi: generateApi
}

/**
 * Generates an API Proxy bundle
 * @param  {string} apiProxy - The name of the API proxy to be generated.
 * @param  {object} options - Command line options provided
 */
async function generateApi(apiProxy, options) {
  console.log("generateApi")

  try {
    let destination = options.destination || path.join(__dirname, '../../../api_bundles')

    if (destination.substr(-1) === '/') {
      destination = destination.substr(0, destination.length - 1)
    }

    const api = await parser.validate(options.source);
    console.log("API name: %s, Version: %s", api.info.title, api.info.version);
    console.log('Source specification is via: %s %s', (api.openapi ? 'OAS' : 'Swagger'), (api.openapi ? api.openapi : api.swagger))
    console.log('API name: %s, Version: %s', api.info.title, api.info.version)
    console.log('Destination: %s', destination)
    generateSkeleton(apiProxy, options)
    await generateProxyEndPoint(apiProxy, options, api)
  }
  catch (err) {
    console.error(err);
  }
}