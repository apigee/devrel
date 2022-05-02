/**
 * Copyright 2022 Google LLC
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

import Handlebars from 'handlebars'
import { ApigeeTemplatePlugin, proxyEndpoint, PlugInResult } from '../interfaces'

/**
 * Plugin for traffic quota templating
 * @date 2/14/2022 - 8:17:36 AM
 *
 * @export
 * @class QuotaPlugin
 * @typedef {QuotaPlugin}
 * @implements {ApigeeTemplatePlugin}
 */
export class QuotaPlugin implements ApigeeTemplatePlugin {
  snippet = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <Quota continueOnError="false" enabled="true" name="Quota-{{index}}" type="calendar">
      <DisplayName>Quota-{{index}}</DisplayName>
      <Properties/>
      <Allow count="{{count}}" countRef="request.header.allowed_quota"/>
      <Interval ref="request.header.quota_count">1</Interval>
      <Distributed>false</Distributed>
      <Synchronous>false</Synchronous>
      <TimeUnit ref="request.header.quota_timeout">{{timeUnit}}</TimeUnit>
      <StartTime>2022-1-20 12:00:00</StartTime>
      <AsynchronousConfiguration>
          <SyncIntervalInSeconds>20</SyncIntervalInSeconds>
          <SyncMessageCount>5</SyncMessageCount>
      </AsynchronousConfiguration>
  </Quota>`;

  template = Handlebars.compile(this.snippet);

  /**
   * Applies the template logic for traffic quotas
   * @date 2/14/2022 - 8:18:32 AM
   *
   * @param {proxyEndpoint} inputConfig
   * @param {Map<string, any>} processingVars
   * @return {Promise<PlugInResult>}
   */
  applyTemplate (inputConfig: proxyEndpoint, processingVars: Map<string, object>): Promise<PlugInResult> {
    return new Promise((resolve) => {
      const fileResult: PlugInResult = new PlugInResult()

      if (inputConfig.quotas && inputConfig.quotas.length > 0) {
        fileResult.files = []
        for (const i in inputConfig.quotas) {
          if (inputConfig.quotas[i].count > 0) {
            fileResult.files.push({
              path: '/policies/Quota-' + (Number(i) + 1).toString() + '.xml',
              contents: this.template({
                index: (Number(i) + 1),
                count: inputConfig.quotas[i].count,
                timeUnit: inputConfig.quotas[i].timeUnit
              })
            });

            // TODO: refactor to get rid of ugly Map string object here
            // eslint-disable-next-line @typescript-eslint/ban-types
            (processingVars.get('preflow_request_policies') as Object[]).push({ name: 'Quota-' + (Number(i) + 1).toString() })
          }
        }
      }

      resolve(fileResult)
    })
  }
}
