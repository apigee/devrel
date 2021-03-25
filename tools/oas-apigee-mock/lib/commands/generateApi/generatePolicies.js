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

var fs = require('fs')
var path = require('path')
var mkdirp = require('mkdirp')
var assign = require('lodash.assign')
var serviceUtils = require('../../util/service.js')
var quota = require('../../policy_templates/quota/quota.js')
var spike = require('../../policy_templates/spikeArrest/spikeArrest.js')
var raiseFault = require('../../policy_templates/raise-fault/raise.js')
var verifyApiKey = require('../../policy_templates/security/apikey.js')
var oauth2 = require('../../policy_templates/security/verifyAccessToken.js')
var assignMessage = require('../../policy_templates/assign-message/assign-message.js')
var async = require('async')

module.exports = function generatePolicies(apiProxy, options, api, cb) {

  console.log("generatePolicies")

  var destination = options.destination || path.join(__dirname, '../../../api_bundles')
  if (destination.substr(-1) === '/') {
    destination = destination.substr(0, destination.length - 1)
  }
  var rootDirectory = destination + '/' + apiProxy + '/apiproxy'
  var validationCount = 0
  var services = serviceUtils.servicesToArray(api)

  console.log("services.length:" + services.length)

  async.each(services, function (service, callback) {
    // Perform operation on file here.
    var xmlStrings = []
    var serviceName = service.name
    var provider = service.provider
    var serviceOptions = service.options
    var xmlString = ''

    if (provider.indexOf('assignMessage') > -1) {
      xmlString = assignMessage.assignMessageTemplate(serviceOptions, serviceName)
      xmlStrings.push({ xmlString: xmlString, serviceName: serviceName })
    }
    if (provider.indexOf('quota') > -1) {
      // Add Quota Policy
      xmlString = quota.quotaGenTemplate(serviceOptions, serviceName)
      xmlStrings.push({ xmlString: xmlString, serviceName: serviceName })
    }
    if (provider.indexOf('spike') > -1) {
      // Add spike Policy
      xmlString = spike.spikeArrestGenTemplate(serviceOptions, serviceName)
      xmlStrings.push({ xmlString: xmlString, serviceName: serviceName })
    }
    if (provider.indexOf('cache') > -1) {
      // Add cache Policies
      xmlString = cache.responseCacheGenTemplate(serviceOptions, serviceName)
      xmlStrings.push({ xmlString: xmlString, serviceName: serviceName })
    }
    if (provider.indexOf('cors') > -1) {
      // Add cors Policies
      xmlString = cors.corsGenTemplate(serviceOptions, serviceName)
      xmlStrings.push({ xmlString: xmlString, serviceName: serviceName })
    }
    if (provider.indexOf('headers') > -1) {
      // Add header Policies
      xmlString = headers.headersGenTemplate(serviceOptions, serviceName)
      xmlStrings.push({ xmlString: xmlString, serviceName: serviceName })
    }
    if (provider.indexOf('regex') > -1) {
      // Add regex Policies
      xmlString = regex.regexGenTemplate(serviceOptions, serviceName)
      xmlStrings.push({ xmlString: xmlString, serviceName: serviceName })
      // filter
      mkdirp.sync(rootDirectory + '/resources/jsc')
      var js = path.join(__dirname, '../../resource_templates/jsc/JavaScriptFilter.js')
      fs.createReadStream(js).pipe(fs.createWriteStream(rootDirectory + '/resources/jsc/' + serviceName + '.js'))
      // regex
      var qs = path.join(__dirname, '../../resource_templates/jsc/querystringDecode.js')
      fs.createReadStream(qs).pipe(fs.createWriteStream(rootDirectory + '/resources/jsc/' + serviceName + '-querystring.js'))
      var x = regex.regularExpressions()
      var wstream = fs.createWriteStream(rootDirectory + '/resources/jsc/regex.js')
      wstream.write(new Buffer('var elements = ' + JSON.stringify(x) + ';'))
      wstream.end()
    }
    if (provider.indexOf('raiseFault') > -1) {
      // Add RaiseFault Policy
      xmlString = raiseFault.raiseFaultGenTemplate(serviceOptions, serviceName)
      xmlStrings.push({ xmlString: xmlString, serviceName: serviceName })
    }
    if (provider.indexOf('input-validation') > -1) {
      assign(serviceOptions, { resourceUrl: 'jsc://input-validation.js' })
      xmlString = validations.validationsGenTemplate(serviceOptions, serviceName)
      xmlStrings.push({ xmlString: xmlString, serviceName: serviceName })
      var extractVarsOptions = {
        name: 'Extract-Path-Parameters',
        displayName: 'Extract Path Parameters',
        api: api
      }
      xmlString = extractVars.extractVarsGenTemplate(extractVarsOptions, extractVarsOptions.name)
      xmlStrings.push({ xmlString: xmlString, serviceName: 'extractPathParameters' })
    }
    if (provider.indexOf('output-validation') > -1) {
      assign(serviceOptions, { resourceUrl: 'jsc://schema-validation.js' })
      xmlString = validations.validationsGenTemplate(serviceOptions, serviceName)
      xmlStrings.push({ xmlString: xmlString, serviceName: serviceName })
    }
    if (validationCount === 0 && (provider.indexOf('input-validation') > -1 || provider.indexOf('output-validation') > -1)) {
      validationCount++ // Only do this once.
      mkdirp.sync(rootDirectory + '/resources/jsc')
      // output validation
      var bu = path.join(__dirname, '../../resource_templates/jsc/bundle-policify.js')
      fs.createReadStream(bu).pipe(fs.createWriteStream(rootDirectory + '/resources/jsc/bundle-policify.js'))
      js = path.join(__dirname, '../../resource_templates/jsc/SchemaValidation.js')
      fs.createReadStream(js).pipe(fs.createWriteStream(rootDirectory + '/resources/jsc/schema-validation.js'))
      // var ru = path.join(__dirname, '../../resource_templates/jsc/Regex.js');
      // fs.createReadStream(ru).pipe(fs.createWriteStream(rootDirectory + '/resources/jsc/regex-utils.js'));
      // input validation
      js = path.join(__dirname, '../../resource_templates/jsc/InputValidation.js')
      fs.createReadStream(js).pipe(fs.createWriteStream(rootDirectory + '/resources/jsc/input-validation.js'))
      // api
      x = validations.validationsSchemas(api)
      wstream = fs.createWriteStream(rootDirectory + '/resources/jsc/api.js')
      wstream.write(new Buffer('var api = ' + JSON.stringify(x) + ';'))
      wstream.end()
    }

    if (provider.indexOf('raiseInputValidationFault') > -1) {
      // Add RaiseFault Policy
      xmlString = raiseFault.raiseFaultGenTemplate(serviceOptions, serviceName)
      xmlStrings.push({ xmlString: xmlString, serviceName: serviceName })
    }
    if (provider.indexOf('raiseOutputValidationFault') > -1) {
      // Add RaiseFault Policy
      xmlString = raiseFault.raiseFaultGenTemplate(serviceOptions, serviceName)
      xmlStrings.push({ xmlString: xmlString, serviceName: serviceName })
    }
    if (provider.indexOf('oauth') > -1 && (serviceName === 'apiKeyQuery' || serviceName === 'apiKeyHeader')) {
      // Add cache Policies
      xmlString = verifyApiKey.apiKeyGenTemplate(serviceOptions, serviceName)
      xmlStrings.push({ xmlString: xmlString, serviceName: serviceName })
    }
    if (provider.indexOf('oauth') > -1 && (serviceName === 'oauth2')) {
      // Add cache Policies
      xmlString = oauth2.verifyAccessTokenGenTemplate(serviceOptions, 'verifyAccessToken')
      xmlStrings.push({ xmlString: xmlString, serviceName: serviceName })
    }

    var writeCnt = 0
    xmlStrings.forEach(function writeFile(xmlString) {
      fs.writeFile(rootDirectory + '/policies/' + xmlString.serviceName + '.xml', xmlString.xmlString, function (err) {
        if (err) {
          callback(err, {})
        }
        writeCnt++
        if (writeCnt === xmlStrings.length) {
          callback(null, {})
        }
      })
    })
  }, function (err) {
    // if any of the file processing produced an error, err would equal that error
    if (err) {
      cb(err, {})
    } else {
      cb(null, {})
    }
  })
}
