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

import yaml from 'js-yaml'
import { ApigeeConverterPlugin, ApigeeTemplateInput } from '../interfaces'

/**
 * Converter from OpenAPI spec v3 format to ApigeeTemplateInput
 * @date 2/11/2022 - 10:36:31 AM
 *
 * @export
 * @class OpenApiV3Converter
 * @typedef {OpenApiV3Converter}
 * @implements {ApigeeConverterPlugin}
 */
export class OpenApiV3Converter implements ApigeeConverterPlugin {
  /**
   * Converts input string in OpenAPI v3 YAML format to ApigeeTemplateInput (if possible)
   * @date 2/11/2022 - 10:36:51 AM
   *
   * @param {string} input Input string in OpenAPI v3 YAML format
   * @return {Promise<ApigeeTemplateInput>} ApigeeTemplateInput object (or undefined if not possible to convert)
   */
  convertInput(input: string): Promise<ApigeeTemplateInput> {
    return new Promise((resolve, reject) => {
      try {
        const specObj: any = yaml.load(input)

        if (specObj && specObj.servers && specObj.servers.length > 0) {
          const result = new ApigeeTemplateInput({
            name: specObj.info.title.replace(' ', '-'),
            endpoints: [
              {
                name: 'default',
                basePath: Object.keys(specObj.paths)[0].replace('/', ''),
                target: {
                  name: 'default',
                  url: specObj.servers[0].url.replace('http://', '').replace('https://', '')
                }
              }
            ]
          })

          resolve(result)
        } else {
          reject(new Error('Conversion not possible'))
        }
      } catch (error) {
        reject(error)
      }
    })
  }
}
