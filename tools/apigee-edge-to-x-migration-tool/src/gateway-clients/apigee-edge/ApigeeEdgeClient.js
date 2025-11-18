/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import fs from 'fs';
import temp from 'temp';
import Bottleneck from 'bottleneck';
import querystring from 'node:querystring';
import inquirer from 'inquirer';
import Logger from '../../utils/logHandler.js';
import { pipeline } from 'node:stream/promises';

temp.track();

class ApigeeEdgeClient {
  /**
   * @type {string}
   */
  baseUrl = null;

  /**
   * @type {string}
   */
  org = null;

  /**
   * @type {string}
   */
  username = null;

  /**
   * @type {string}
   */
  password = null;

  /**
   * @type {string}
   */
  token = null;

  /**
   * @type {Bottleneck}
   */
  limiter = null;

  /**
   * Create an Apigee Edge Management API client
   *
   * @param {string} baseUrl 
   * @param {string} org 
   */
  constructor(baseUrl, org, options = {}) {
    const {
      username = null,
      password = null
    } = options ?? {};

    this.baseUrl = baseUrl;
    this.org = org;
    this.username = username;
    this.password = password;

    // Apigee edge has a rate limit of 10,000 calls per minute to its management APIs
    const managementApiRateLimitPerMinute = 10000;

    // Set our rate limit to 10% of what Apigee allows, so we don't interrupt day-to-day operations on the production gateway
    const rateLimitPerMinute = managementApiRateLimitPerMinute * 0.1;

    // Restrict management API calls to 10% of the Apigee managemnet API rate limit per minute
    this.limiter = new Bottleneck({
      reservoir: rateLimitPerMinute,
      reservoirRefreshAmount: rateLimitPerMinute,
      reservoirRefreshInterval: 60 * 1000, // Every minute
      minTime: 5 // Enforce slight spacing between calls
    })
  }

  /**
   * Make a GET request to the gateway
   *
   * @param {string} url 
   * @returns 
   */
  async get(url, options = {}) {
    return this.call(url, 'GET', null, options);
  }

  /**
   * Make a POST request to the gateway
   *
   * @param {string} url 
   * @param {*} body 
   * @returns 
   */
  async post(url, body, options = {}) {
    return this.call(url, 'POST', body, options);
  }

  /**
   * Make a PUT request to the gateway
   *
   * @param {string} url 
   * @param {*} body 
   * @returns 
   */
  async put(url, body, options = {}) {
    return this.call(url, 'PUT', body, options);
  }

  /**
   * Make a DELETE request to the gateway
   *
   * @param {string} url 
   * @returns 
   */
  async delete(url, options = {}) {
    return this.call(url, 'DELETE', null, options);
  }

  /**
   * Get a bearer token to use when calling Apigee Edge Management APIs
   *
   * @returns {Promise<string>}
   */
  async _getToken() {
    if (this.token) {
      return this.token;
    }

    if (!this.username || !this.password) {
      const { username, password } = await inquirer.prompt([
        {
          name: 'username',
          type: 'input',
          message: 'Your Apigee Edge username'
        },
        {
          name: 'password',
          type: 'password',
          message: 'Your Apigee Edge password'
        }
      ]);

      this.username = username;
      this.password = password;
    }

    return fetch('https://login.apigee.com/oauth/token', {
      method: 'POST',
      body: querystring.stringify({
        username: this.username,
        password: this.password,
        grant_type: 'password'
      }),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
        'Accept': 'application/json;charset=utf-8',
        'Authorization': 'Basic ZWRnZWNsaTplZGdlY2xpc2VjcmV0'
      }
    }).then(async res => {
      if (!res.ok) {
        throw new Error(`Apigee Edge authentication error status: ${res.status}, message: ${await res.text() || res.statusText}`);
      }

      const resJson = JSON.parse(await res.text());

      this.token = resJson?.access_token ?? null;

      if (!this.token) {
        throw new Error('Apigee Edge did not return an access token.');
      }

      return this.token;
    }).catch(error => {
      throw new Error(`Unable to authenticate to Apigee Edge using username and password. ${error.message}`);
    });
  }

  /**
   * 
   * @param {string} url 
   * @param {string} method 
   * @param {*} body 
   * @returns 
   */
  async call(url, method, body, options = {}) {
    return this.limiter.schedule(async () => {

      if (!this.bearerToken) {
        this.bearerToken = await this._getToken();
      }

      Logger.getInstance().log('apigee_edge_call', `Apigee Edge Call: ${method} ${this.baseUrl}${this.org}${url}`, body);

      return fetch(`${this.baseUrl}${this.org}${url}`, {
        method,
        body,
        headers: {
          'accept': '*/*',
          'Content-type': 'application/json',
          'Authorization': `Bearer ${this.bearerToken}`
        }
      }).then(async res => {
        if (!res.ok) {
          throw new Error(await res.text() || res.statusText);
        }

        if (res.headers.get('content-type').includes('application/json')) {
          return res.json();
        }

        if (res.headers.get('content-type').includes('application/octet-stream')) {
          const downloadFilePath = options?.downloadFilePath ?? null;
          const writeStream = downloadFilePath ? fs.createWriteStream(downloadFilePath) : temp.createWriteStream();
          const writeStreamPath = writeStream.path;

          return pipeline(res.body, writeStream).then(() => writeStreamPath);
        }

        return res.text();
      }).catch(error => {
        Logger.getInstance().error('apigee_edge_call', `Error response from Apigee Edge ${method} ${this.baseUrl}${this.org}${url}`, error.message);

        throw error;
      });
    })
  }
}

export default ApigeeEdgeClient;