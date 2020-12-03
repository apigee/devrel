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
} = require('cucumber')
const puppeteer = require('puppeteer')
const org = process.env.APIGEE_ORG
const env = 'test'
const state ='123-abc'
const scope = 'openid email address'

Given('I navigate to the authorize page', async function() {
  this.browser = await puppeteer.launch({
    ignoreHTTPSErrors: true,
    headless:false,
    args: ["--no-sandbox"]
  })
  this.page = await this.browser.newPage()
  return await this.page.goto('https://' + org + '-' + env + 
    '.apigee.net/v1/oauth20/authorize?client_id=' + this.apickli.scenarioVariables.clientId
    + '&redirect_uri=https://httpbin.org/get&response_type=code&state=' + state +'&scope=' + scope)
})

When('I sign in and consent', async function() {
  //fill in login page
  await this.page.click('#username')
  await this.page.keyboard.type(this.apickli.scenarioVariables.username)
  await this.page.click('#password')
  await this.page.keyboard.type(this.apickli.scenarioVariables.password)
  
  //submit
  await Promise.all([
    this.page.click('#submit'),
    this.page.waitForNavigation()
  ])

  //return submit
  return await Promise.all([
    this.page.click('#submit'),
    this.page.waitForNavigation()
  ])

})

Then('I am redirected to the Client App', function(cb) {
  cb(this.page.url().indexOf('https://httpbin.org/get') === -1)
})

Then('I receive an auth code in a query param',  function(cb) {
  cb(this.page.url().indexOf('code=') === -1)
})

Then('I store the auth code in global scope', async function() {
  this.apickli.setGlobalVariable('authCode', 
    new URL(this.page.url()).searchParams.get('code'))
})

Then('I store the state parameter in global scope', async function() {
  this.apickli.setGlobalVariable('state',state)
})

After(async function() {
  if (this.browser) this.browser.close()
})
