@JSONEndpoint
Feature:
  As an API Developer
  I want to generate a JSON threat
  So that I can verify JSON threat protection

  Scenario: Generate a valid and conform JSON content and verify it
    When I GET /json?width=`width`&depth=`depth`&length=`length`&height=`height`
    Then response code should be 200
    And response body should be valid json

  Scenario: Generate a JSON threat (depth attack) and reject it
    When I GET /json?width=`width`&depth=20&length=`length`&height=`height`
    Then response code should be 400
    And response body should be valid json

  Scenario: Generate a JSON threat (width attack) and reject it
    When I GET /json?width=20&depth=`depth`&length=`length`&height=`height`
    Then response code should be 400
    And response body should be valid json

  Scenario: Generate a JSON threat (length attack) and reject it
    When I GET /json?width=`width`&depth=`depth`&length=35&height=`height`
    Then response code should be 400
    And response body should be valid json

  Scenario: Generate a JSON threat (height attack) and reject it
    When I GET /json?width=`width`&depth=`depth`&length=`length`&height=20
    Then response code should be 400
    And response body should be valid json