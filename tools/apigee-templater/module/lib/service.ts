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

import archiver from 'archiver'
import fs from 'fs'
import path from 'path'
import { performance } from 'perf_hooks'
import { ApigeeTemplateService, ApigeeTemplateInput, ApigeeTemplateProfile, PlugInResult, PlugInFile, ApigeeConverterPlugin, GenerateResult } from './interfaces'
import { ProxiesPlugin } from './plugins/proxies.plugin'
import { TargetsPlugin } from './plugins/targets.plugin'
import { TargetsBigQueryPlugin } from './plugins/targets.bigquery.plugin'
import { AuthSfPlugin } from './plugins/auth.sf.plugin'
import { AuthApiKeyPlugin } from './plugins/auth.apikey.plugin'
import { QuotaPlugin } from './plugins/traffic.quota.plugin'
import { SpikeArrestPlugin } from './plugins/traffic.spikearrest.plugin'
import { Json1Converter } from './converters/json1.plugin'
import { Json2Converter } from './converters/json2.plugin'
import { OpenApiV3Converter } from './converters/openapiv3.yaml.plugin'

/**
 * ApigeeGenerator runs the complete templating operation with all injected plugins
 * @date 2/14/2022 - 8:22:47 AM
 *
 * @export
 * @class ApigeeGenerator
 * @typedef {ApigeeGenerator}
 * @implements {ApigeeTemplateService}
 */
export class ApigeeGenerator implements ApigeeTemplateService {
  converterPlugins: ApigeeConverterPlugin[] = [
    new Json1Converter(),
    new Json2Converter(),
    new OpenApiV3Converter()
  ];

  profiles: Record<string, ApigeeTemplateProfile> = {
    default: {
      plugins: [
        new SpikeArrestPlugin(),
        new AuthApiKeyPlugin(),
        new AuthSfPlugin(),
        new QuotaPlugin(),
        new TargetsPlugin(),
        new ProxiesPlugin()
      ]
    },
    bigquery: {
      plugins: [
        new SpikeArrestPlugin(),
        new AuthApiKeyPlugin(),
        new AuthSfPlugin(),
        new QuotaPlugin(),
        new TargetsBigQueryPlugin(),
        new ProxiesPlugin()
      ]
    }
  };

  // eslint-disable-next-line valid-jsdoc
  /**
   * Creates an instance of ApigeeGenerator.
   * @date 3/16/2022 - 9:09:47 AM
   *
   * @constructor
   * @param {?Record<string, ApigeeTemplateProfile>} [customProfiles]
   * @param {?ApigeeConverterPlugin[]} [customInputConverters]
   */
  constructor(customProfiles?: Record<string, ApigeeTemplateProfile>, customInputConverters?: ApigeeConverterPlugin[]) {
    // Override any profiles passed optionally in constructor
    if (customProfiles) {
      for (const [key, value] of Object.entries(customProfiles)) {
        this.profiles[key] = value
      }
    }
    // Replace input converters if any passed in contructor
    if (customInputConverters) {
      this.converterPlugins = customInputConverters
    }
  }

  /**
   * Converts an input string into a template input object
   * @date 2/14/2022 - 8:24:03 AM
   *
   * @param {string} inputString
   * @return {Promise<ApigeeTemplateInput>}
   */
  convertStringToTemplate(inputString: string): Promise<ApigeeTemplateInput> {
    return new Promise((resolve, reject) => {
      const conversions: Promise<ApigeeTemplateInput>[] = []
      for (const plugin of this.converterPlugins) {
        conversions.push(plugin.convertInput(inputString))
      }

      Promise.allSettled(conversions).then((values) => {
        let conversionSuccessful = false

        for (const value of values) {
          if (value.status == 'fulfilled') {
            conversionSuccessful = true
            resolve(value.value)
            break
          }
        }

        if (!conversionSuccessful) { reject(new Error('No conversion was found for the input string!')) }
      })
    })
  }

  /**
   * Generates a proxy bundle based on an input string
   * @date 2/14/2022 - 8:25:31 AM
   *
   * @param {string} inputString
   * @param {string} outputDir
   * @return {Promise<GenerateResult>} Result including path to generated proxy bundle
   */
  generateProxyFromString(inputString: string, outputDir: string): Promise<GenerateResult> {
    return new Promise((resolve, reject) => {
      this.convertStringToTemplate(inputString).then((result) => {
        this.generateProxy(result, outputDir).then((generateResult) => {
          resolve(generateResult)
        })
      }).catch((error) => {
        console.error(error)
        reject(error)
      })
    })
  }

  /**
   * Main generate proxy method with correct input object
   * @date 2/14/2022 - 8:26:00 AM
   *
   * @param {ApigeeTemplateInput} genInput
   * @param {string} outputDir
   * @return {Promise<GenerateResult>} GenerateResult object including path to generated proxy bundle
   */
  generateProxy(genInput: ApigeeTemplateInput, outputDir: string): Promise<GenerateResult> {
    return new Promise((resolve, reject) => {
      const startTime = performance.now()

      const result: GenerateResult = {
        success: true,
        duration: 0,
        message: '',
        localPath: ''
      }

      const processingVars: Map<string, object> = new Map<string, object>()
      const newOutputDir = outputDir + '/' + genInput.name + '/apiproxy'
      fs.mkdirSync(newOutputDir, { recursive: true })

      fs.mkdirSync(newOutputDir + '/proxies', { recursive: true })
      fs.mkdirSync(newOutputDir + '/targets', { recursive: true })
      fs.mkdirSync(newOutputDir + '/policies', { recursive: true })
      fs.mkdirSync(newOutputDir + '/resources', { recursive: true })

      for (const endpoint of genInput.endpoints) {
        // Initialize variables for endpoint
        processingVars.set('preflow_request_policies', [])
        processingVars.set('preflow_response_policies', [])
        processingVars.set('postflow_request_policies', [])
        processingVars.set('postflow_response_policies', [])

        if (process.env.PROJECT) {
          if (!endpoint.parameters) endpoint.parameters = {};
          endpoint.parameters.PROJECT = process.env.PROJECT;
        }

        if (Object.keys(this.profiles).includes(genInput.profile)) {
          for (const plugin of this.profiles[genInput.profile].plugins) {
            plugin.applyTemplate(endpoint, processingVars).then((result: PlugInResult) => {
              result.files.forEach((file: PlugInFile) => {
                fs.mkdirSync(path.dirname(newOutputDir + file.path), { recursive: true })
                fs.writeFileSync(newOutputDir + file.path, file.contents)
              })
            })
          }
        } else {
          reject(new Error(`Profile ${genInput.profile} was not found!  No conversion is possible without a valid profile (current profiles available: ${Object.keys(this.profiles)})`))
        }
      }

      const archive = archiver('zip')
      archive.on('error', function (err: Error) {
        reject(err)
      })

      archive.directory(outputDir + '/' + genInput.name, false)

      const output = fs.createWriteStream(outputDir + '/' + genInput.name + '.zip')

      archive.on('end', () => {
        // Zip is finished, cleanup files
        fs.rmSync(outputDir + '/' + genInput.name, { recursive: true })
        const endTime = performance.now()
        result.duration = endTime - startTime
        result.message = `Proxy generation completed in ${Math.round(result.duration)} milliseconds.`
        result.localPath = outputDir + '/' + genInput.name + '.zip'
        result.template = genInput

        resolve(result)
      })

      archive.pipe(output)
      archive.finalize()
    })
  }
}
