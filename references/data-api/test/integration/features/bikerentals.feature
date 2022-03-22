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

Feature:
  As an API consumer
  I want to be able to use an API facade on top of a data platform
  So that I consume data as an API product

  Scenario: Get the default number of bike rentals
    When I GET /bikerentals
    Then response code should be 200
    And response body path $ should be of type array with length 5
    And response body path $.[0].rental_id should not be null
    And response body path $.[0].bike_id should not be null
    And response body path $.[0].duration should not be null

  Scenario: Get a specific number of bike rentals
    Given I set query parameters to
      | parameter | value |
      | limit | 10 |
    When I GET /bikerentals
    Then response code should be 200
    And response body path $ should be of type array with length 10

  Scenario: Reject too large number of bike rentals request
    Given I set query parameters to
      | parameter | value |
      | limit | 101 |
    When I GET /bikerentals
    Then response code should be 400

  Scenario: Reject invalid limit requests
    Given I set query parameters to
      | parameter | value |
      | limit | 6;SELECT * from something; |
    When I GET /bikerentals
    Then response code should be 400

  Scenario: Attempt to inject non-numeric limits
    Given I set query parameters to
      | parameter | value |
      | limit | 6;SELECT * from something; |
    When I GET /bikerentals
    Then response code should be 400

  Scenario: Return specific fields only
    Given I set query parameters to
      | parameter | value |
      | fields |rental_id,bike_id|
    When I GET /bikerentals
    Then response code should be 200
    And response body path $.[0].rental_id should not be null
    And response body path $.[0].bike_id should not be null
    And response body path $.[0].duration should be null
