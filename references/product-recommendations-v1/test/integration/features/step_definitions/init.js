/* jshint node:true */
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

