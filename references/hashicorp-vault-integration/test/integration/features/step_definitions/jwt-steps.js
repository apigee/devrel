/**
  Copyright 2020 Google LLC

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

const {
    Given,
    When,
    Then,
    After
} = require('@cucumber/cucumber')

const jose = require('jose')
const {JSONPath: jsonPath} = require('jsonpath-plus');
const assert = require('assert');

Then(/^I clear request$/, async function() {

    this.apickli.headers = {};
    this.apickli.formParameters = {};
    this.apickli.requestBody = '';
    this.apickli.httpRequestOptions = {};
    this.apickli.queryParameters = {};
});

Then('I store JWKS in global scope', async function() {

    this.apickli.setGlobalVariable('jwks', this.apickli.getResponseObject().body)
})


Then(/^scenario variable (.*) path (.*) should be (.*)/, async function( varjson, path, regexp){

    const json = this.apickli.scenarioVariables[ varjson ];
    const val = jsonPath( path, json)[0];

    const regexpObj = new RegExp( regexp );
    assert.ok( regexpObj.test( val ) )
})

Then(/^I decode JWT token value of scenario variable (.*) as (.*) in scenario scope$/, async function(varJwt, varJson) {

    this.apickli.storeValueInScenarioScope(varJson, jose.JWT.decode( this.apickli.scenarioVariables[varJwt] ));
})

Then(/^value of scenario variable (.*) is valid JWT token$/, async function(variable) {

    const jwks = JSON.parse( this.apickli.getGlobalVariable( 'jwks') );

    const  publicKeys = jose.JWKS.asKeyStore(jwks, 'ES256')

    const jwt = this.apickli.scenarioVariables[variable]
    jose.JWT.verify(
        jwt,
        publicKeys,
        {
            issuer: this.apickli.scenarioVariables['issuer'],
            audience: this.apickli.scenarioVariables['audience'],
            clockTolerance: "5s"
            //,    maxTokenAge: 31536000
        }
    )
})
