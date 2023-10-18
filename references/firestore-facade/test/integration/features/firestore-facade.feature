# Copyright 2023 Google LLC
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

@firestore-facade-end2end

Feature:
  As a Client App 
  I want to access an API exposed on Apigee that is connected with a Firestore db
  So that I can retrieve data stored in the Firestore db
  
  Scenario: Client App Accesses the firestore-facade API exposed on Apigee
    When I GET /
    Then response code should be 200
    And response body should be valid json
    And response body path $.code should be FIRESTORE-MOCK001
