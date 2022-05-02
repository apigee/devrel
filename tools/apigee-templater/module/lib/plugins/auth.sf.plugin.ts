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
import { ApigeeTemplatePlugin, proxyEndpoint, authTypes, PlugInResult } from '../interfaces'

/**
 * Template plugin to evaluate a sharedflow for authn
 * @date 2/14/2022 - 8:12:42 AM
 *
 * @export
 * @class AuthSfPlugin
 * @typedef {AuthSfPlugin}
 * @implements {ApigeeTemplatePlugin}
 */
export class AuthSfPlugin implements ApigeeTemplatePlugin {
  snippet = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <FlowCallout continueOnError="false" enabled="true" name="VerifyJWT">
      <DisplayName>VerifyJWT</DisplayName>
      <FaultRules/>
      <Properties/>
      <Parameters>
          {{#if audience}}
          <Parameter name="audience">{{audience}}</Parameter>
          {{/if}}
          {{#if roles}}
          <Parameter name="roles">{{roles}}</Parameter>
          {{/if}}
          {{#if issuerVer1}}
          <Parameter name="issuerVer1">{{issuerVer1}}</Parameter>
          {{/if}}
          {{#if issuerVer2}}
          <Parameter name="issuerVer2">{{issuerVer2}}</Parameter>
          {{/if}}
      </Parameters>
      <SharedFlowBundle>Shared-Flow_GCP_API</SharedFlowBundle>
  </FlowCallout>`;

  template = Handlebars.compile(this.snippet);

  /**
   * Applies the plugin logic for templating
   * @date 2/14/2022 - 8:13:23 AM
   *
   * @param {proxyEndpoint} inputConfig
   * @param {Map<string, object>} processingVars
   * @return {Promise<PlugInResult>}
   */
  applyTemplate (inputConfig: proxyEndpoint, processingVars: Map<string, object>): Promise<PlugInResult> {
    return new Promise((resolve) => {
      const fileResult: PlugInResult = new PlugInResult()

      if (inputConfig.auth && inputConfig.auth.filter(e => e.type === authTypes.sharedflow).length > 0) {
        const authConfig = inputConfig.auth.filter(e => e.type === authTypes.sharedflow)[0]

        fileResult.files = [
          {
            path: '/policies/VerifyJWT.xml',
            contents: this.template({
              audience: authConfig.parameters.audience,
              roles: authConfig.parameters.roles,
              issuerVer1: authConfig.parameters.issuerVer1,
              issuerVer2: authConfig.parameters.issuerVer2
            })
          }
        ];

        // TODO: refactor to get rid of ugly Map string object here
        // eslint-disable-next-line @typescript-eslint/ban-types
        (processingVars.get('preflow_request_policies') as Object[]).push({ name: 'VerifyJWT' })
      }

      resolve(fileResult)
    })
  }
}
