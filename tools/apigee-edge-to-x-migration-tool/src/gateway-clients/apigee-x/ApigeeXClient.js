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

import temp from 'temp';
import fs from 'fs';
import Bottleneck from 'bottleneck';
import querystring from 'node:querystring';
import crypto from 'crypto';
import Logger from '../../utils/logHandler.js';
import urlSafeBase64Encode from '../../utils/urlSafeBase64Encode.js'
import { pipeline } from 'node:stream/promises';

temp.track();

class ApigeeXClient {
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
  serviceAccount = null;

  /**
   * @type {string}
   */
  token = null;

  /**
   * @type {Bottleneck}
   */
  limiter = null;

  /**
   * 
   * @param {string} baseUrl 
   * @param {string} org 
   */
  constructor(baseUrl, org, serviceAccount) {
    this.baseUrl = baseUrl;
    this.org = org;
    this.serviceAccount = serviceAccount;

    // Apigee X has a rate limit of 10,000 calls per minute to its management APIs
    const managementApiRateLimitPerMinute = 10000;
    const rateLimitPerMinute = managementApiRateLimitPerMinute * 0.1;

    // Restrict management API calls to 10% of the Apigee managemnet API rate limit per minute
    this.limiter = new Bottleneck({
      reservoir: rateLimitPerMinute,
      reservoirRefreshAmount: rateLimitPerMinute,
      reservoirRefreshInterval: 60 * 1000, // Every 60 seconds
      minTime: 5 // Enforce slight spacing between calls
    })
  }

  /**
   * 
   * @param {string} url 
   * @returns 
   */
  async get(url, options = {}) {
    return this.call(url, 'GET', null, options);
  }

  /**
   * 
   * @param {string} url 
   * @param {*} body 
   * @returns 
   */
  async post(url, body, options = {}) {
    return this.call(url, 'POST', body, options);
  }

  /**
   * 
   * @param {string} url 
   * @param {*} body 
   * @returns 
   */
  async put(url, body, options = {}) {
    return this.call(url, 'PUT', body, options);
  }

  /**
   * 
   * @param {string} url 
   * @returns 
   */
  async delete(url, options = {}) {
    return this.call(url, 'DELETE', null, options);
  }

  /**
   * Get a bearer token to use when calling Apigee X Management APIs.
   *
   * @returns {Promise<string>}
   */
  async _getToken() {
    if (this.token) {
      return this.token;
    }

    const issueDate = Date.now() / 1000;
    const privateKeyId = this.serviceAccount?.account_json_key?.private_key_id ?? null;
    const privateKey = this.serviceAccount?.account_json_key?.private_key ?? null;
    const clientEmail = this.serviceAccount?.account_json_key?.client_email ?? null;

    const jwtHeader = {
      alg: "RS256",
      typ: "JWT",
      kid: privateKeyId
    };

    const jwtClaims = {
      iss: clientEmail,
      //sub: 'charles.thomas1@concentrix.com',
      scope: "https://www.googleapis.com/auth/cloud-platform",
      aud: "https://oauth2.googleapis.com/token",
      exp: issueDate + (60 * 15), // 15 minutes
      iat: issueDate
    }

    const jws = `${urlSafeBase64Encode(JSON.stringify(jwtHeader))}.${urlSafeBase64Encode(JSON.stringify(jwtClaims))}`;

    // Create a sign object
    const sign = crypto.createSign('RSA-SHA256');

    // Update the sign object with the data
    sign.update(jws);

    // Sign the data
    const signature = sign.sign(privateKey, 'base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

    const jwt = `${jws}.${signature}`;

    return fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      body: querystring.stringify({
        assertion: jwt,
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer'
      }),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
        'Accept': 'application/json;charset=utf-8',
        'Authorization': 'Basic ZWRnZWNsaTplZGdlY2xpc2VjcmV0'
      }
    }).then(async res => {
      if (!res.ok) {
        throw new Error(`Apigee X authentication error status: ${res.status}, message: ${await res.text() || res.statusText}`);
      }

      const resJson = await res.json();

      this.token = resJson?.access_token ?? null;

      if (!this.token) {
        throw new Error('Apigee X did not return an access token.');
      }

      return this.token;
    }).catch(error => {
      Logger.getInstance().error('apigee_x_client', 'Unable to get bearer token', error.message);
      throw new Error(`Unable to authenticate to Apigee X using service account. ${error.message}`);
    });
  }

  /**
   * 
   * @param {string} url 
   * @param {string} method 
   * @param {string} body 
   * @returns 
   */
  async call(url, method, body, options = {}) {
    return this.limiter.schedule(async () => {
      const bearerToken = await this._getToken();

      Logger.getInstance().log('apigee_x_call', `Apigee X Call: ${method} ${this.baseUrl}${this.org}${url}`, body);

      return fetch(`${this.baseUrl}${this.org}${url}`, {
        method,
        body,
        headers: {
          'accept': '*/*',
          'Content-type': body instanceof Buffer ? 'application/octet-stream' : 'application/json',
          'Authorization': `Bearer ${bearerToken}`
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
        Logger.getInstance().error('apigee_x_call', `Error response from Apigee X ${method} ${this.baseUrl}${this.org}${url}`, error.message);

        throw error;
      });
    })
  }
}

export default ApigeeXClient;