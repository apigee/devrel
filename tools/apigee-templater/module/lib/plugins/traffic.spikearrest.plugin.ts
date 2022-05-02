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
 * Plugin for templating spike arrests
 * @date 2/14/2022 - 8:21:02 AM
 *
 * @export
 * @class SpikeArrestPlugin
 * @typedef {SpikeArrestPlugin}
 * @implements {ApigeeTemplatePlugin}
 */
export class SpikeArrestPlugin implements ApigeeTemplatePlugin {
  snippet = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <SpikeArrest continueOnError="false" enabled="true" name="Spike-Arrest-1">
      <DisplayName>Spike Arrest-1</DisplayName>
      <Properties/>
      <Identifier ref="request.header.some-header-name"/>
      <MessageWeight ref="request.header.weight"/>
      <Rate>{{rate}}</Rate>
  </SpikeArrest>`;

  template = Handlebars.compile(this.snippet);

  /**
   * Applies the template logic for spike arrests
   * @date 2/14/2022 - 8:21:23 AM
   *
   * @param {proxyEndpoint} inputConfig
   * @param {Map<string, object>} processingVars
   * @return {Promise<PlugInResult>}
   */
  applyTemplate (inputConfig: proxyEndpoint, processingVars: Map<string, object>): Promise<PlugInResult> {
    return new Promise((resolve) => {
      const fileResult: PlugInResult = new PlugInResult()

      if (inputConfig.spikeArrest) {
        fileResult.files = [
          {
            path: '/policies/Spike-Arrest-1.xml',
            contents: this.template({
              rate: inputConfig.spikeArrest.rate
            })
          }
        ];

        // TODO: refactor to get rid of ugly Map string object here
        // eslint-disable-next-line @typescript-eslint/ban-types
        (processingVars.get('preflow_request_policies') as Object[]).push({ name: 'Spike-Arrest-1' })
      }

      resolve(fileResult)
    })
  }
}
