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
const apickli = require('apickli')
const {
  Before,
  Given,
  setDefaultTimeout
} = require('cucumber')

const org = process.env.APIGEE_ORG
const env = process.env.APIGEE_ENV 
const clientId = 'dummy-client_id-123' 
const clientSecret = 'dummy-client_secret-456'
const username = 'janedoe' 
const password = 'dummy-password'

Before(function() {
  this.apickli = new apickli.Apickli('https',
    org + '-' + env + '.apigee.net')
  this.apickli.scenarioVariables.clientId = clientId
  this.apickli.scenarioVariables.clientSecret = clientSecret
  this.apickli.scenarioVariables.username = username
  this.apickli.scenarioVariables.password = password
})

setDefaultTimeout(60 * 1000)
