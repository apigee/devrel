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

import { ApigeeConverterPlugin, ApigeeTemplateInput } from '../interfaces'

/**
 * Converter from input string JSON format to ApigeeConverterPlugin
 * @date 2/11/2022 - 10:30:33 AM
 *
 * @export
 * @class Json1Converter
 * @typedef {Json1Converter}
 * @implements {ApigeeConverterPlugin}
 */
export class Json1Converter implements ApigeeConverterPlugin {
  /**
   * Converts input string in JSON format to the ApigeeTemplateInput object (if possible)
   * @date 2/11/2022 - 10:31:04 AM
   *
   * @param {string} input Input string in JSON format
   * @return {Promise<ApigeeTemplateInput>} ApigeeTemplateInput object or undefined if wrong input format
   */
  convertInput(input: string): Promise<ApigeeTemplateInput> {
    return new Promise((resolve, reject) => {
      let result: ApigeeTemplateInput

      try {
        const inputData = JSON.parse(input)
        if (inputData.name && inputData.endpoints) {
          result = inputData as ApigeeTemplateInput
          resolve(result)
        } else { reject(new Error('Conversion not posible, data incomplete')) }
      } catch (error) {
        // Conversion failed..
        reject(new Error('Conversion failed'))
      }
    })
  }
}
