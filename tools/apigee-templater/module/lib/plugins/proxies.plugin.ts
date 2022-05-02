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
import { ApigeeTemplatePlugin, PlugInResult, proxyEndpoint } from '../interfaces'

/**
 * Creates proxy endpoints for the template
 * @date 2/14/2022 - 8:14:22 AM
 *
 * @export
 * @class ProxiesPlugin
 * @typedef {ProxiesPlugin}
 * @implements {ApigeeTemplatePlugin}
 */
export class ProxiesPlugin implements ApigeeTemplatePlugin {
  snippet = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <ProxyEndpoint name="default">
      <PreFlow name="PreFlow">
          <Request>
            {{#each preflow_request_policies}}
              <Step>
                <Name>{{this.name}}</Name>
              </Step>
            {{/each}}
          </Request>
          <Response/>
      </PreFlow>
      <Flows/>
      <PostFlow name="PostFlow">
          <Request/>
          <Response/>
      </PostFlow>
      <HTTPProxyConnection>
          <BasePath>{{basePath}}</BasePath>
      </HTTPProxyConnection>
      <RouteRule name="{{targetName}}">
          <TargetEndpoint>{{targetName}}</TargetEndpoint>
      </RouteRule>
  </ProxyEndpoint>`;

  template = Handlebars.compile(this.snippet);

  /**
   * Apply template for proxy endpoints
   * @date 2/14/2022 - 8:15:04 AM
   *
   * @param {proxyEndpoint} inputConfig
   * @param {Map<string, object>} processingVars
   * @return {Promise<PlugInResult>}
   */
  applyTemplate(inputConfig: proxyEndpoint, processingVars: Map<string, object>): Promise<PlugInResult> {
    return new Promise((resolve) => {
      const fileResult: PlugInResult = new PlugInResult()
      fileResult.files = [
        {
          path: '/proxies/' + inputConfig.name + '.xml',
          contents: this.template(
            {
              basePath: inputConfig.basePath,
              targetName: inputConfig.target.name,
              preflow_request_policies: processingVars.get('preflow_request_policies'),
              preflow_response_policies: processingVars.get('preflow_response_policies'),
              postflow_request_policies: processingVars.get('postflow_request_policies'),
              postflow_response_policies: processingVars.get('postflow_response_policies')
            })
        }
      ]

      resolve(fileResult)
    })
  }
}
