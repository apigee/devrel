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

'use strict';

var apickli = require('apickli');
var config = require('../../test-config.json');
var apps = require('../../devAppKeys.json');
var keys = {};

console.log('CURL TO: [https://' + config.apiconfig.domain + config.apiconfig.basepath + ']');
getCredsFromExport(config.apiconfig.app, config.apiconfig.product);
console.log( "KEYS: " + keys.clientId + " " + keys.clientSecret);

module.exports = function() {
    // cleanup before every scenario
    this.Before(function(scenario, callback) {
        this.apickli = new apickli.Apickli('https', config.apiconfig.domain + config.apiconfig.basepath);
        
        this.apickli.storeValueInScenarioScope("apiproxy", config.apiconfig.apiproxy);
        this.apickli.storeValueInScenarioScope("basepath", config.apiconfig.basepath);
        this.apickli.storeValueInScenarioScope("clientId", keys.clientId);
        this.apickli.storeValueInScenarioScope("clientSecret", keys.clientSecret);
        callback();
    });
};

// Just take the first match, no expiry or status available
function getCredsFromExport(appName, productName){
  for(var app in apps){
    if(apps[app].name === appName){
      var credentials = apps[app].credentials;
      for(var credential in credentials){
        var products = credentials[credential].apiProducts;
        for(var product in products){
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

