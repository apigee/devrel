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

import { ApigeeTemplateService, ApigeeGenerator } from '../src'
import fs from 'fs'
import { expect } from 'chai'
import { describe } from 'mocha'

console.log('starting')
const apigeeGenerator: ApigeeTemplateService = new ApigeeGenerator()

describe('Generate simple normal JSON 1 proxy', () => {
  return it('should produce a valid proxy bundle', () => {
    const input = fs.readFileSync('./test/data/input1.json', 'utf-8')
    return apigeeGenerator.generateProxyFromString(input, 'test/proxies').then((response) => {
      expect(response.success).to.equal(true)
      expect(response.duration).to.greaterThan(0)
      expect(fs.existsSync(response.localPath)).to.equal(true)
    })
  })
})

describe('Generate custom JSON 2 proxy', () => {
  return it('should produce a valid proxy bundle', () => {
    const input = fs.readFileSync('./test/data/input2.json', 'utf-8')
    return apigeeGenerator.generateProxyFromString(input, 'test/proxies').then((response) => {
      expect(response.success).to.equal(true)
      expect(response.duration).to.greaterThan(0)
      expect(fs.existsSync(response.localPath)).to.equal(true)
    })
  })
})

describe('Generate BigQuery query proxy bundle', () => {
  return it('should produce a valid proxy bundle', () => {
    const input = fs.readFileSync('./test/data/bigquery_query_input.json', 'utf-8')
    return apigeeGenerator.generateProxyFromString(input, 'test/proxies').then((response) => {
      expect(response.success).to.equal(true)
      expect(response.duration).to.greaterThan(0)
      expect(fs.existsSync(response.localPath)).to.equal(true)
    })
  })
})

describe('Generate BigQuery table proxy bundle', () => {
  return it('should produce a valid proxy bundle', () => {
    const input = fs.readFileSync('./test/data/bigquery_table_input.json', 'utf-8')
    return apigeeGenerator.generateProxyFromString(input, 'test/proxies').then((response) => {
      expect(response.success).to.equal(true)
      expect(response.duration).to.greaterThan(0)
      expect(fs.existsSync(response.localPath)).to.equal(true)
    })
  })
})

describe('Generate OpenAPI v3 proxy', () => {
  return it('should produce a valid proxy bundle', () => {
    const input = fs.readFileSync('./test/data/petstore.yaml', 'utf-8')
    return apigeeGenerator.generateProxyFromString(input, 'test/proxies').then((response) => {
      expect(response.success).to.equal(true)
      expect(response.duration).to.greaterThan(0)
      expect(fs.existsSync(response.localPath)).to.equal(true)
    })
  })
})
