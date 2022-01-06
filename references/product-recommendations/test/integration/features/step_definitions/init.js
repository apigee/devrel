/* jshint node:true */
/**
  Copyright 2021 Google LLC
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
      https://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/
/* eslint-disable no-invalid-this */ // See usage in apickli Documentation
"use strict";

const apickli = require("apickli");
const config = require("../../test-config.json");
const apps = require("../../devAppKeys.json");
const keys = {};

console.log("CURL TO: [https://" + config.apiconfig.domain + config.apiconfig.basepath + "]");
getCredsFromExport(config.apiconfig.app, config.apiconfig.product);
console.log( "KEYS: " + keys.clientId + " " + keys.clientSecret);

const { Before, setDefaultTimeout } = require("@cucumber/cucumber");

setDefaultTimeout(10 * 1000); // this is in ms

Before(function () {
  this.apickli = new apickli.Apickli('https', config.apiconfig.domain + config.apiconfig.basepath);
  this.apickli.storeValueInScenarioScope("apiproxy", config.apiconfig.apiproxy);
  this.apickli.storeValueInScenarioScope("basepath", config.apiconfig.basepath);
  this.apickli.storeValueInScenarioScope("clientId", keys.clientId);
  this.apickli.storeValueInScenarioScope("clientSecret", keys.clientSecret);
});

/**
 * Just take the first match, no expiry or status available.
 * @param {string} appName App name.
 * @param {string} productName API product name.
 */
function getCredsFromExport(appName, productName){
  for(let app=0; app<apps.length; app++){
    if(apps[app].name === appName){
      const credentials = apps[app].credentials;
      for(let credential=0; credential<credentials.length; credential++){
        const products = credentials[credential].apiProducts;
        for(let product=0; product<products.length; product++){
          if(products[product].apiproduct === productName){
            keys.clientId = credentials[credential].consumerKey;
            keys.clientSecret = credentials[credential].consumerSecret;
            return;
          }
        }
      }
    }
  }
}

