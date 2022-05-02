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
import { ApigeeTemplatePlugin, PlugInResult, proxyEndpoint, authTypes } from '../interfaces'

/**
 * Plugin class for handling API Key template requests
 * @date 2/14/2022 - 8:08:34 AM
 *
 * @export
 * @class AuthApiKeyPlugin
 * @typedef {AuthApiKeyPlugin}
 * @implements {ApigeeTemplatePlugin}
 */
export class AuthApiKeyPlugin implements ApigeeTemplatePlugin {
  apikey_snippet = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <VerifyAPIKey async="false" continueOnError="false" enabled="true" name="VerifyApiKey">
      <DisplayName>Verify API Key</DisplayName>
      <APIKey ref="request.queryparam.apikey"/>
  </VerifyAPIKey>`;

  removekey_snippet = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <AssignMessage async="false" continueOnError="false" enabled="true" name="RemoveApiKey">
      <DisplayName>Remove Query Param apikey</DisplayName>
      <Remove>
          <QueryParams>
              <QueryParam name="apikey"/>
          </QueryParams>
      </Remove>
      <IgnoreUnresolvedVariables>true</IgnoreUnresolvedVariables>
      <AssignTo createNew="false" transport="http" type="request"/>
  </AssignMessage>`;

  apikey_template = Handlebars.compile(this.apikey_snippet);
  removekey_template = Handlebars.compile(this.removekey_snippet);

  /**
   * Applies the template for this plugin
   * @date 2/14/2022 - 8:09:38 AM
   *
   * @param {proxyEndpoint} inputConfig
   * @param {Map<string, any>} processingVars
   * @return {Promise<PlugInResult>} Result of the plugin templating
   */
  applyTemplate (inputConfig: proxyEndpoint, processingVars: Map<string, object>): Promise<PlugInResult> {
    return new Promise((resolve) => {
      const fileResult: PlugInResult = new PlugInResult()

      if (inputConfig.auth && inputConfig.auth.filter(e => e.type === authTypes.apikey).length > 0) {
        fileResult.files = [
          {
            path: '/policies/VerifyApiKey.xml',
            contents: this.apikey_template({})
          },
          {
            path: '/policies/RemoveApiKey.xml',
            contents: this.removekey_template({})
          }
        ];

        // TODO: refactor to get rid of ugly Map string object here
        // eslint-disable-next-line @typescript-eslint/ban-types
        (processingVars.get('preflow_request_policies') as Object[]).push({ name: 'VerifyApiKey' });
        // eslint-disable-next-line @typescript-eslint/ban-types
        (processingVars.get('preflow_request_policies') as Object[]).push({ name: 'RemoveApiKey' })
      }

      resolve(fileResult)
    })
  }
}
