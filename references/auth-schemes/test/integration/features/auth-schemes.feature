# Copyright 2021 Google LLC
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

Feature:
  As an Apigee platform explorer
  I want to experiment with different API auth schemes
  So that I can understand how they can be implemented

  Scenario: Using a valid API Key
    Given I set API-Key header to `clientId`
    When I GET /api-key
    Then response code should be 200

  Scenario: Using an invalid API Key
    Given I set API-Key header to foobar
    When I GET /api-key
    Then response code should be 401
    And response body should be valid json
    And response body path $.fault.detail.errorcode should be oauth.v2.InvalidApiKey

  Scenario: [Helper] Obtain OAuth Access Token
    Given I set form parameters to
      |parameter|value|
      |grant_type|client_credentials|
    And I have basic authentication credentials `clientId` and `clientSecret`
    When I POST to /helpers/oauth
    Then response code should be 200
    And response body should be valid json
    And I store the value of body path $.access_token as accessToken in global scope
  
  Scenario: Using a valid OAuth Access Token
    Given I set Authorization header to "Bearer `accessToken`"
    When I GET /oauth-token
    Then response code should be 200
  
  Scenario: Using an invalid OAuth Access Token
    Given I set Authorization header to "Bearer foobar"
    When I GET /oauth-token
    Then response code should be 401
    And response body should be valid json
    And response body path $.fault.detail.errorcode should be keymanagement.service.invalid_access_token

  Scenario: [Helper] Obtain JWT
    When I POST to /helpers/jwt
    Then response code should be 200
    And response header Generated-JWT should exist
    And I store the value of response header Generated-JWT as jwt in global scope

  Scenario: Using a valid JWT
    Given I set JWT header to `jwt`
    When I GET /jwt
    Then response code should be 200

  Scenario: Using an invalid JWT
    Given I set JWT header to foobar
    When I GET /jwt
    Then response code should be 401
    And response body should be valid json
    And response body path $.fault.detail.errorcode should be steps.jwt.InvalidToken

  Scenario: Using valid basic auth credentials
    Given I have basic authentication credentials alex and universe
    When I GET /basic-auth
    Then response code should be 200

  Scenario: Using invalid basic auth credentials
    Given I have basic authentication credentials nobody and mypassword
    When I GET /basic-auth
    Then response code should be 401
    And response body should be valid json
    And response body path $.error should be invalid credentials provided

  Scenario: Requesting an unknown path
    When I GET /foobar
    Then response code should be 404
    And response body should be valid json
    And response body path $.error should be no route configured for /foobar
    