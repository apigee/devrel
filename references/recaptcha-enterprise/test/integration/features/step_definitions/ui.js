/**
  Copyright 2022 Google LLC
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
const puppeteer = require('puppeteer')
const assert = require('assert')
const hostname = "apigeex.iloveapis.io"
const basePath = "/token/v1"

Given('I navigate to the token page', async function() {
  this.browser = await puppeteer.launch({
    ignoreHTTPSErrors: true,
    headless: true,
    args: ["--no-sandbox"]
  })
  this.page = await this.browser.newPage()
  return await this.page.goto('https://' + hostname + basePath)
})

Then('I extract reCAPTCHA token', async function() {
 
  const pageContent = await this.page.content();
  //await this.page.close();
  console.log(pageContent)
  await this.page.close();
  return pageContent;
})

After(async function() {
  if (this.browser) this.browser.close()
})
