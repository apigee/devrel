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
const fs = require('fs').promises;
const path = require('path')
const assignMessage = require('../../policy_templates/assign-message/assign-message.js')

module.exports = async function generateProxyEndPoint(apiProxy, options, api) {
  let useCors
  let destination = options.destination || path.join(__dirname, '../../../api_bundles')
  if (destination.substr(-1) === '/') {
    destination = destination.substr(0, destination.length - 1)
  }

  const rootDirectory = destination + '/' + apiProxy + '/apiproxy'
  const root = builder.create('ProxyEndpoint')
  root.att('name', 'default')
  root.ele('Description', {}, api.info.title)
  const preFlow = root.ele('PreFlow', { name: 'PreFlow' })

  // Add steps to preflow.
  preFlow.ele('Request')
  preFlow.ele('Response')

  const flows = root.ele('Flows', {})

  for (const apiPath in api.paths) {
    if (Object.prototype.hasOwnProperty.call(api.paths, apiPath)) {

      for (const resource in api.paths[apiPath]) {
        if (Object.prototype.hasOwnProperty.call(api.paths[apiPath], resource)) {

          const resourceItem = api.paths[apiPath][resource]
          resourceItem.operationId = resourceItem.operationId || resource.toUpperCase() + ' ' + apiPath
          const flow = flows.ele('Flow', { name: resourceItem.operationId })
          const flowCondition = '(proxy.pathsuffix MatchesPath &quot;' + apiPath + '&quot;) and (request.verb = &quot;' + resource.toUpperCase() + '&quot;)'
          flow.ele('Condition').raw(flowCondition)
          flow.ele('Description', {}, resourceItem.summary)

          // Adding AM Policies to response
          responsePipe = flow.ele('Response')

          if (resourceItem['responses']) {

            for (const service in resourceItem['responses']) {
              if (Object.prototype.hasOwnProperty.call(resourceItem['responses'], service)) {

                step = responsePipe.ele('Step', {})
                const stepName = ('AM-' + resourceItem.operationId + '-' + service).replace(/\s+/g, '-').toLowerCase()
                step.ele('Name', {}, stepName)

                // Create Policy
                const options = {};
                options.name = stepName
                options.statusCode = service

                if (resourceItem['responses'][service].content != null) {
                  options.payload = JSON.stringify(resourceItem['responses'][service].content["application/json"].example)
                } else {
                  options.payload = '';
                }

                const xmlString = assignMessage.assignMessageTemplate(options)
                await fs.writeFile(rootDirectory + '/policies/' + stepName + '.xml', xmlString)

              }
            }
          }
        }
      } // for loop for resources ends here
    }
  }  // for loop for paths ends here

  const httpProxyConn = root.ele('HTTPProxyConnection')

  let specBasePath = undefined
  if (api.servers !== undefined && api.servers.length > 0 && api.servers[0].url !== undefined) {
    try {
      specBasePath = (new URL(api.servers[0].url, 'https://apigee.google.com')).pathname
    } catch (error) {
      // fail and use proxy name as fallback
    }
  }

  if (options.basepath) {
    httpProxyConn.ele('BasePath', {}, options.basepath)
  } else if (specBasePath !== undefined) {
    httpProxyConn.ele('BasePath', {}, specBasePath)
  } else {
    httpProxyConn.ele('BasePath', {}, '/' + apiProxy)
  }

  const virtualhosts = (options.virtualhosts) ? options.virtualhosts.split(',') : ['secure']
  virtualhosts.forEach(function (virtualhost) {
    httpProxyConn.ele('VirtualHost', {}, virtualhost)
  })

  if (useCors) {
    const routeRule1 = root.ele('RouteRule', { name: 'noRoute' })
    routeRule1.ele('Condition', {}, 'request.verb == "OPTIONS"')
  }

  // No back end, Assign message policies are used for responses, add noroute RouteRule
  root.ele('RouteRule', { name: 'noroute' })

  const xmlString = root.end({ pretty: true, indent: '  ', newline: '\n' })
  await fs.writeFile(rootDirectory + '/proxies/default.xml', xmlString)
}