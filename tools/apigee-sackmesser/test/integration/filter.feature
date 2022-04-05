Feature: Sackmesser Example
  As an API consumer
  I want to interact with the Apigee Mock Target
  So that I know that the proxy deployment was successful

  Scenario: I love APIs
    When I GET /iloveapis
    Then response code should be 200
    And response body should contain I <3 APIs

  Scenario: Valid json
    When I GET /json
    Then response code should be 200
    And response body should be valid json

  Scenario: Invalid path
    When I GET /not-part-of-oas
    Then response code should be 400
