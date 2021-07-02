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
    Given I set body to {"key": "test-entry", "value":"test-value"}
    And I set Content-Type header to application/json
    When I POST to /keyvaluemaps/kvmtestmap/entries
    Then response code should be 200
    And response body path $.value should be test-value
    And response body path $.key should be test-entry
    And response header Authorization should not exist

  Scenario: Retrieve an entry in the KVM
    When I GET /keyvaluemaps/kvmtestmap/entries/test-entry
    Then response code should be 200
    And response body path $.value should be test-value
    And response body path $.key should be test-entry

  Scenario: Create an entry containing JSON in the KVM
    Given I set body to {"key": "test-json", "value":"{\"a\": 42}"}
    And I set Content-Type header to application/json
    When I POST to /keyvaluemaps/kvmtestmap/entries
    Then response code should be 200
    And response body path $.value should be {\"a\": 42}
    And response body path $.key should be test-json
    And response header Authorization should not exist

  Scenario: Retrieve an entry in the KVM
    When I GET /keyvaluemaps/kvmtestmap/entries/test-json
    Then response code should be 200
    And response body path $.value should be {\"a\": 42}
    And response body path $.key should be test-json

  Scenario: Retrieve a wrong entry in the KVM
    When I GET /keyvaluemaps/kvmtestmap/entries/wrong-entry
    Then response code should be 404

  Scenario: Retrieve with a wrong mapname
    When I GET /keyvaluemaps/wrongtestmap/entries/test-entry
    Then response code should be 404

  Scenario: Delete an entry in the KVM
    When I DELETE /keyvaluemaps/kvmtestmap/entries/test-entry
    Then response code should be 200
    And response body path $.value should be test-value
    And response body path $.key should be test-entry

  Scenario: Delete an invalid entry in the KVM
    When I DELETE /keyvaluemaps/kvmtestmap/entries/wrong-entry
    Then response code should be 404

  Scenario: Delete an entry with a wrong mapname
    When I DELETE /keyvaluemaps/wrongtestmap/entries/test-entry
    Then response code should be 404

  Scenario: Query an invalid resource in the proxy
    When I DELETE /keyvaluemaps/invalidresource
    Then response code should be 404

  Scenario: Invalid PUT call
    Given I set body to {"key": "test-entry", "value":"test-value"}
    And I set Content-Type header to application/json
    When I PUT to /keyvaluemaps/kvmtestmap/entries
    Then response code should be 403

  @flaky
  Scenario: Retrieve an entry after deleting it
    When I GET /keyvaluemaps/kvmtestmap/entries/test-entry
    Then response code should be 404

