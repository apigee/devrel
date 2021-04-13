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
  quotaTemplate: quotaTemplate,
  quotaGenTemplate: quotaGenTemplate
}

/**
 * Generates XML for quota policy
 * @param  {object} options - Policy Options
 * @return {string}
 */
function quotaTemplate(options) {
  const aysnc = options.async || 'false'
  const continueOnError = options.continueOnError || 'false'
  const enabled = options.enabled || 'true'
  const name = options.name || 'Quota-' + random.randomText()
  const qType = options.qType || 'calendar'
  const displayName = options.displayName || name
  const count = options.count || 2000
  const countRef = options.countRef || 'request.header.allowed_quota'
  const interval = options.interval || 1
  const intervalRef = options.intervalRef || 'request.header.quota_count'
  const distributed = options.distributed || 'false'
  const sync = options.sync || 'false'
  const timeUnit = options.timeUnit || 'month'
  const timeUnitRef = options.timeUnitRef || 'request.header.quota_timeout'
  const d = new Date()
  const dateString = d.getFullYear() + '-' + (('0' + (d.getMonth() + 1)).slice(-2)) + '-' + ('0' + d.getDate()).slice(-2) +
    ' ' + d.getHours() + ':' + (d.getMinutes() - 2) + ':' + d.getSeconds()
  const startTime = options.startTime || dateString
  const quota = builder.create('Quota')
  quota.att('async', aysnc)
  quota.att('continueOnError', continueOnError)
  quota.att('enabled', enabled)
  quota.att('name', name)
  quota.att('type', qType)
  quota.ele('DisplayName', {}, displayName)
  quota.ele('Allow', { count: count, countRef: countRef })
  quota.ele('Interval', { ref: intervalRef }, interval)
  quota.ele('Distributed', {}, distributed)
  quota.ele('Synchronous', {}, sync)
  quota.ele('TimeUnit', { ref: timeUnitRef }, timeUnit)
  quota.ele('StartTime', {}, startTime)
  const xmlString = quota.end({ pretty: true, indent: '  ', newline: '\n' })
  return xmlString
}

/**
 * Generates XML for quota policy
 * @param  {object} options
 * @param  {string} name
 * @return {string}
 */
function quotaGenTemplate(options, name) {
  const templateOptions = options
  templateOptions.count = options.allow
  templateOptions.name = name

  return quotaTemplate(templateOptions)
}
