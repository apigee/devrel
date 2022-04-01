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

@recaptcha-enterprise-end2end

Feature:
  As a Client App 
  I want to access the protected resource of an API
  So that I can retrieve different types of information and data
  
  Scenario: Client App Accesses Protected Resource with a valid reCAPTCHA token - Risk Score:1 (human)
    Given I set x-recaptcha-token header to X-RECAPTCHA-TOKEN-1
    Given I set x-apikey header to `clientId`
    When I GET /headers
    Then response code should be 200
    And response body should be valid json
