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
const serviceUtils = require('../../util/service.js')
const assignMessage = require('../../policy_templates/assign-message/assign-message.js')

module.exports = function generateProxyEndPoint(apiProxy, options, api, cb) {
  let useCors
  let destination = options.destination || path.join(__dirname, '../../../api_bundles')
  if (destination.substr(-1) === '/') {
    destination = destination.substr(0, destination.length - 1)
  }

  let rootDirectory = destination + '/' + apiProxy + '/apiproxy'
  let root = builder.create('ProxyEndpoint')
  root.att('name', 'default')
  root.ele('Description', {}, api.info.title)
  let preFlow = root.ele('PreFlow', { name: 'PreFlow' })

  // Add steps to preflow.
  preFlow.ele('Request')
  preFlow.ele('Response')

  let flows = root.ele('Flows', {})

  let allowedVerbs = ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'HEAD', 'TRACE', 'CONNECT', 'PATCH']
  for (let apiPath in api.paths) {

    for (let resource in api.paths[apiPath]) {

      if (allowedVerbs.indexOf(resource.toUpperCase()) >= 0) {

        let resourceItem = api.paths[apiPath][resource]
        resourceItem.operationId = resourceItem.operationId || resource.toUpperCase() + ' ' + apiPath
        let flow = flows.ele('Flow', { name: resourceItem.operationId })
        let flowCondition = '(proxy.pathsuffix MatchesPath &quot;' + apiPath + '&quot;) and (request.verb = &quot;' + resource.toUpperCase() + '&quot;)'
        flow.ele('Condition').raw(flowCondition)
        flow.ele('Description', {}, resourceItem.summary)

        // Adding AM Policies to response
        responsePipe = flow.ele('Response')

        if (resourceItem['responses']) {

          for (let service in resourceItem['responses']) {
            step = responsePipe.ele('Step', {})
            let stepName = ('AM-' + resourceItem.operationId + '-' + service).replace(/\s+/g, '-').toLowerCase()
            step.ele('Name', {}, stepName)

            // Create Policy
            let options = new Object();
            options.name = stepName
            options.statusCode = service

            if (resourceItem['responses'][service].content != null) {
              options.payload = JSON.stringify(resourceItem['responses'][service].content["application/json"].example)
            } else {

              options.payload = '';
            }

            let xmlString = assignMessage.assignMessageTemplate(options)

            fs.writeFile(rootDirectory + '/policies/' + stepName + '.xml', xmlString, function (err) {
              if (err) {
                callback(err, {})
              }
            })

          }
        }

      }  // methods check ends here
    }  // for loop for resources ends here
  }  // for loop for paths ends here

  let httpProxyConn = root.ele('HTTPProxyConnection')
  if (api.basePath !== undefined) {
    httpProxyConn.ele('BasePath', {}, api.basePath)
  } else {
    httpProxyConn.ele('BasePath', {}, '/' + apiProxy)
  }
  let virtualhosts = (options.virtualhosts) ? options.virtualhosts.split(',') : ['secure']
  virtualhosts.forEach(function (virtualhost) {
    httpProxyConn.ele('VirtualHost', {}, virtualhost)
  })

  if (useCors) {
    let routeRule1 = root.ele('RouteRule', { name: 'noRoute' })
    routeRule1.ele('Condition', {}, 'request.verb == "OPTIONS"')
  }

  //No back end, Assign message policies are used for responses, add noroute RouteRule
  root.ele('RouteRule', { name: 'noroute' })

  let xmlString = root.end({ pretty: true, indent: '  ', newline: '\n' })
  fs.writeFile(rootDirectory + '/proxies/default.xml', xmlString, function (err) {
    if (err) {
      return cb(err, {})
    }
    cb(null, {})
  })
}