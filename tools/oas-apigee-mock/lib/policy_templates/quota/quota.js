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
var random = require('../../util/random.js')

module.exports = {
  quotaTemplate: quotaTemplate,
  quotaGenTemplate: quotaGenTemplate
}

function quotaTemplate (options) {
  var aysnc = options.async || 'false'
  var continueOnError = options.continueOnError || 'false'
  var enabled = options.enabled || 'true'
  var name = options.name || 'Quota-' + random.randomText()
  var qType = options.qType || 'calendar'
  var displayName = options.displayName || name
  var count = options.count || 2000
  var countRef = options.countRef || 'request.header.allowed_quota'
  var interval = options.interval || 1
  var intervalRef = options.intervalRef || 'request.header.quota_count'
  var distributed = options.distributed || 'false'
  var sync = options.sync || 'false'
  var timeUnit = options.timeUnit || 'month'
  var timeUnitRef = options.timeUnitRef || 'request.header.quota_timeout'
  var d = new Date()
  var dateString = d.getFullYear() + '-' + (('0' + (d.getMonth() + 1)).slice(-2)) + '-' + ('0' + d.getDate()).slice(-2) +
                   ' ' + d.getHours() + ':' + (d.getMinutes() - 2) + ':' + d.getSeconds()
  var startTime = options.startTime || dateString
  var quota = builder.create('Quota')
  quota.att('async', aysnc)
  quota.att('continueOnError', continueOnError)
  quota.att('enabled', enabled)
  quota.att('name', name)
  quota.att('type', qType)
  quota.ele('DisplayName', {}, displayName)
  quota.ele('Allow', {count: count, countRef: countRef})
  quota.ele('Interval', {ref: intervalRef}, interval)
  quota.ele('Distributed', {}, distributed)
  quota.ele('Synchronous', {}, sync)
  quota.ele('TimeUnit', {ref: timeUnitRef}, timeUnit)
  quota.ele('StartTime', {}, startTime)
  var xmlString = quota.end({ pretty: true, indent: '  ', newline: '\n' })
  return xmlString
}

function quotaGenTemplate (options, name) {
  var templateOptions = options
  templateOptions.count = options.allow
  templateOptions.name = name

  return quotaTemplate(templateOptions)
}
