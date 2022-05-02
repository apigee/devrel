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

/** A proxy target describes a target URL to route traffic to */
export class proxyTarget {
  name = 'default';
  url?= '';
  query?= '';
  table?= '';
  authScopes?= [];
}

/** A proxy endpoint describes a basepath, targets and other proxy features */
export class proxyEndpoint {
  name = 'TestProxy';
  basePath = '/test';
  target: proxyTarget = {
    name: 'default',
    url: 'https://httpbin.org'
  };
  auth?: authConfig[];
  quotas?: quotaConfig[];
  spikeArrest?: spikeArrestConfig;
  parameters?: { [key: string]: string } = {};
}

/** Describes a proxy to be templated */
export class ApigeeTemplateInput {
  name = 'MyProxy';
  profile = 'default';
  endpoints: proxyEndpoint[] = [];

  /**
   * Creates an instance of ApigeeTemplateInput.
   * @date 3/16/2022 - 10:18:44 AM
   *
   * @constructor
   * @public
   * @param {?Partial<ApigeeTemplateInput>} [init]
   */
  public constructor(init?: Partial<ApigeeTemplateInput>) {
    Object.assign(this, init)
  }
}

/** Authorization config for an endpoint */
export class authConfig {
  type: authTypes = authTypes.apikey;
  parameters: { [key: string]: string } = {};
}

/** Quota config for an endpoint */
export class quotaConfig {
  count = 5;
  timeUnit = 'minute';
  condition?: string;
}

/** Spike arrest config for an endpoint */
export class spikeArrestConfig {
  rate = '30s';
}

export enum authTypes {
  // eslint-disable-next-line no-unused-vars
  apikey = 'apikey',
  // eslint-disable-next-line no-unused-vars
  jwt = 'jwt',
  // eslint-disable-next-line no-unused-vars
  sharedflow = 'sharedflow'
}

export interface ApigeeTemplateService {
  generateProxyFromString(inputString: string, outputDir: string): Promise<GenerateResult>
  generateProxy(inputConfig: ApigeeTemplateInput, outputDir: string): Promise<GenerateResult>
}

/** The result of the template generation */
export class GenerateResult {
  success = false;
  duration = 0;
  message = '';
  localPath = '';
  template?: ApigeeTemplateInput;
}

/** The result of plugin processing */
export class PlugInResult {
  files: PlugInFile[] = [];
}

/** Plugin file results to be written to disk */
export class PlugInFile {
  path = '';
  contents = '';
}

/** Profile definition with plugins to be used for conversion */
export class ApigeeTemplateProfile {
  plugins: ApigeeTemplatePlugin[] = [];
}

export interface ApigeeTemplatePlugin {
  applyTemplate(inputConfig: proxyEndpoint, processingVars: Map<string, object>): Promise<PlugInResult>
}

export interface ApigeeConverterPlugin {
  convertInput(input: string): Promise<ApigeeTemplateInput>
}
