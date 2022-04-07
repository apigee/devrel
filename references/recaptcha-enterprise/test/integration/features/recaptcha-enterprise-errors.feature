# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

@recaptcha-enterprise-errors

Feature:
  As a Client App 
  I want to access the protected resource of an API
  So that I can retrieve different types of information and data
  
  Scenario: Client App Accesses Protected Resource with an invalid reCAPTCHA token
    Given I set x-recaptcha-token header to X-RECAPTCHA-TOKEN-INVALID
    Given I set x-apikey header to `clientId`
    When I GET /headers
    Then response code should be 400
    And response body should be valid json

  Scenario: Client App Accesses Protected Resource with an invalid API Key
    Given I set x-recaptcha-token header to X-RECAPTCHA-TOKEN-0.7
    Given I set x-apikey header to `xxxxx`
    When I GET /headers
    Then response code should be 401
    And response body should be valid json

  Scenario: Client App Accesses Protected Resource with a valid reCAPTCHA token - Risk Score:0 (bot)
    Given I set x-recaptcha-token header to X-RECAPTCHA-TOKEN-0
    Given I set x-apikey header to `clientId`
    When I GET /headers
    Then response code should be 400
    And response body should be valid json
  
  Scenario: Client App Accesses Protected Resource with a valid reCAPTCHA token - Risk Score:0.1 (bot)
    Given I set x-recaptcha-token header to X-RECAPTCHA-TOKEN-0.1
    Given I set x-apikey header to `clientId`
    When I GET /headers
    Then response code should be 400
    And response body should be valid json

  Scenario: Client App Accesses Protected Resource with a valid reCAPTCHA token - Risk Score:0.2 (bot)
    Given I set x-recaptcha-token header to X-RECAPTCHA-TOKEN-0.2
    Given I set x-apikey header to `clientId`
    When I GET /headers
    Then response code should be 400
    And response body should be valid json
  
  Scenario: Client App Accesses Protected Resource with a valid reCAPTCHA token - Risk Score:0.3 (bot)
    Given I set x-recaptcha-token header to X-RECAPTCHA-TOKEN-0.3
    Given I set x-apikey header to `clientId`
    When I GET /headers
    Then response code should be 400
    And response body should be valid json

  Scenario: Client App Accesses Protected Resource with a valid reCAPTCHA token - Risk Score:0.4 (bot)
    Given I set x-recaptcha-token header to X-RECAPTCHA-TOKEN-0.4
    Given I set x-apikey header to `clientId`
    When I GET /headers
    Then response code should be 400
    And response body should be valid json
  
  Scenario: Client App Accesses Protected Resource with a valid reCAPTCHA token - Risk Score:0.5 (bot)
    Given I set x-recaptcha-token header to X-RECAPTCHA-TOKEN-0.5
    Given I set x-apikey header to `clientId`
    When I GET /headers
    Then response code should be 400
    And response body should be valid json
