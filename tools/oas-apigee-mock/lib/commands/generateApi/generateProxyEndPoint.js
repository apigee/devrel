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
var fs = require('fs')
var path = require('path')
var serviceUtils = require('../../util/service.js')
var assignMessage = require('../../policy_templates/assign-message/assign-message.js')

module.exports = function generateProxyEndPoint(apiProxy, options, api, cb) {
  var useCors
  var destination = options.destination || path.join(__dirname, '../../../api_bundles')
  if (destination.substr(-1) === '/') {
    destination = destination.substr(0, destination.length - 1)
  }

  var rootDirectory = destination + '/' + apiProxy + '/apiproxy'
  var root = builder.create('ProxyEndpoint')
  root.att('name', 'default')
  root.ele('Description', {}, api.info.title)
  var preFlow = root.ele('PreFlow', { name: 'PreFlow' })

  // Add steps to preflow.
  var raiseFaultName
  var requestPipe = preFlow.ele('Request')
  var responsePipe = preFlow.ele('Response')
  var services = serviceUtils.servicesToArray(api)

  var flows = root.ele('Flows', {})

  var allowedVerbs = ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'HEAD', 'TRACE', 'CONNECT', 'PATCH']
  for (var apiPath in api.paths) {

    for (var resource in api.paths[apiPath]) {

      if (allowedVerbs.indexOf(resource.toUpperCase()) >= 0) {

        var resourceItem = api.paths[apiPath][resource]
        resourceItem.operationId = resourceItem.operationId || resource.toUpperCase() + ' ' + apiPath
        var flow = flows.ele('Flow', { name: resourceItem.operationId })
        var flowCondition = '(proxy.pathsuffix MatchesPath &quot;' + apiPath + '&quot;) and (request.verb = &quot;' + resource.toUpperCase() + '&quot;)'
        flow.ele('Condition').raw(flowCondition)
        flow.ele('Description', {}, resourceItem.summary)

        //Adding AM Policies to response
        responsePipe = flow.ele('Response')

        if (resourceItem['responses']) {

          for (var service in resourceItem['responses']) {
            step = responsePipe.ele('Step', {})
            var stepName = ('AM-' + resourceItem.operationId + '-' + service).replace(/\s+/g, '-').toLowerCase()
            step.ele('Name', {}, stepName)

            //Create Policy
            var options
            options.name = stepName
            options.statusCode = service

            if (resourceItem['responses'][service].content != null) {
              options.payload = JSON.stringify(resourceItem['responses'][service].content["application/json"].example)
            } else {

              options.payload = '';
            }

            xmlString = assignMessage.assignMessageTemplate(options)

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

  var httpProxyConn = root.ele('HTTPProxyConnection')
  if (api.basePath !== undefined) {
    httpProxyConn.ele('BasePath', {}, api.basePath)
  } else {
    httpProxyConn.ele('BasePath', {}, '/' + apiProxy)
  }
  var virtualhosts = (options.virtualhosts) ? options.virtualhosts.split(',') : ['secure']
  virtualhosts.forEach(function (virtualhost) {
    httpProxyConn.ele('VirtualHost', {}, virtualhost)
  })

  if (useCors) {
    var routeRule1 = root.ele('RouteRule', { name: 'noRoute' })
    routeRule1.ele('Condition', {}, 'request.verb == "OPTIONS"')
  }

  //No back end, Assign message policies are used for responses
  var routeRule2 = root.ele('RouteRule', { name: 'noroute' })

  var xmlString = root.end({ pretty: true, indent: '  ', newline: '\n' })
  fs.writeFile(rootDirectory + '/proxies/default.xml', xmlString, function (err) {
    if (err) {
      return cb(err, {})
    }
    cb(null, {})
  })
}