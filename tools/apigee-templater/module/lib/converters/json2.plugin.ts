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

import { ApigeeConverterPlugin, ApigeeTemplateInput, authTypes } from '../interfaces'

/**
 * Converter from JSON format 2 to ApigeeTemplateInput
 * @date 2/11/2022 - 10:34:37 AM
 *
 * @export
 * @class Json2Converter
 * @typedef {Json2Converter}
 * @implements {ApigeeConverterPlugin}
 */
export class Json2Converter implements ApigeeConverterPlugin {
  /**
   * Converts input string in JSON format 2 to ApigeeTemplateInput
   * @date 2/11/2022 - 10:35:02 AM
   *
   * @param {string} input Input string in JSON format 2
   * @return {Promise<ApigeeTemplateInput>} ApigeeTemplateInput object or undefined if not possible
   */
  convertInput(input: string): Promise<ApigeeTemplateInput> {
    return new Promise((resolve, reject) => {
      try {
        const obj = JSON.parse(input)

        if (obj.api) {
          try {
            const result = new ApigeeTemplateInput({
              name: obj.product.apiTestBackendProduct.productName,
              endpoints: [
                {
                  name: 'default',
                  basePath: obj.product.apiTestBackendProduct.productName,
                  target: {
                    name: 'default',
                    url: obj.environments[0].backendBaseUrl
                  },
                  auth: [
                    {
                      type: authTypes.sharedflow,
                      parameters: {}
                    }
                  ]
                }
              ]
            })

            if (obj.api.policies && obj.api.policies.inbound && obj.api.policies.inbound.totalThrottlingEnabled) {
              result.endpoints[0].quotas = [{
                count: 200,
                timeUnit: 'day'
              }]
            }

            if (obj.environments && obj.environments.length > 0 && obj.environments[0].backendAudienceConfiguration) {
              if (result && result.endpoints && result.endpoints[0].auth) { result.endpoints[0].auth[0].parameters.audience = obj.environments[0].backendAudienceConfiguration.backendAudience }
            }
            if (obj.api.policies && obj.api.policies.inbound && obj.api.policies.inbound.validateJwtTokenAzureAdV1) {
              if (result && result.endpoints && result.endpoints[0].auth) { result.endpoints[0].auth[0].parameters.issuerVer1 = 'https://issuerv1.idp.com' }
            }
            if (obj.api.policies && obj.api.policies.inbound && obj.api.policies.inbound.validateJwtTokenAzureAdV2) {
              if (result && result.endpoints && result.endpoints[0].auth) { result.endpoints[0].auth[0].parameters.issuerVer2 = 'https://issuerv2.idp.com' }
            }

            resolve(result)
          } catch (error) {
            // Conversion failed..
            reject(error)
          }
        } else { reject(new Error("Format didn't match")) }
      } catch (error) {
        // Conversion failed..
        reject(error)
      }
    })
  }
}
