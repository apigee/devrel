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
 * Plugin for generating targets
 * @date 2/14/2022 - 8:15:26 AM
 *
 * @export
 * @class TargetsPlugin
 * @typedef {TargetsPlugin}
 * @implements {ApigeeTemplatePlugin}
 */
export class TargetsPlugin implements ApigeeTemplatePlugin {
  snippet = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <TargetEndpoint name="{{targetName}}">
      <PreFlow name="PreFlow">
          <Request/>
          <Response/>
      </PreFlow>
      <Flows/>
      <PostFlow name="PostFlow">
          <Request/>
          <Response/>
      </PostFlow>
      <HTTPTargetConnection>
          <URL>{{targetUrl}}</URL>
      </HTTPTargetConnection>
  </TargetEndpoint>`;

  template = Handlebars.compile(this.snippet);

  /**
   * Templates the targets configurations
   * @date 2/14/2022 - 8:15:57 AM
   *
   * @param {proxyEndpoint} inputConfig
   * @param {Map<string, object>} processingVars
   * @return {Promise<PlugInResult>}
   */
  applyTemplate(inputConfig: proxyEndpoint): Promise<PlugInResult> {
    return new Promise((resolve) => {
      const fileResult: PlugInResult = new PlugInResult()

      if (inputConfig.target) {
        fileResult.files = [
          {
            path: '/targets/' + inputConfig.target.name + '.xml',
            contents: this.template({ targetName: inputConfig.target.name, targetUrl: inputConfig.target.url })
          }
        ]
      }

      resolve(fileResult)
    })
  }
}
