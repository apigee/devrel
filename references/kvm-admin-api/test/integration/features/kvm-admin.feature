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
  As an API platform operator
  I want to be able to manipulate entries in a KVM
  So that I can use it to store config values

  Scenario: Create an entry in the KVM
    Given I set body to {"name": "test-entry", "value":"test-value"}
    And I set Content-Type header to application/json
    When I POST to /kvms/kvmap/entries
    Then response code should be 200
    And response body path $.value should be test-value
    And response body path $.name should be test-entry

  Scenario: Retrieve an entry in the KVM
    When I GET /kvms/kvmap/entries/test-entry
    Then response code should be 200
    And response body path $.value should be test-value
    And response body path $.name should be test-entry

  Scenario: Delete an entry in the KVM
    When I DELETE /kvms/kvmap/entries/test-entry
    Then response code should be 200
    And response body path $.value should be test-value
    And response body path $.name should be test-entry
