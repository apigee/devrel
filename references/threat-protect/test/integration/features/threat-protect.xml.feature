@XMLEndpoint
Feature:
  As an API Developer
  I want to generate a XML threat
  So that I can verify XML threat protection

  Scenario: Generate a wellformed and conform XML content and verify it
    When I GET /xml?width=`width`&depth=`depth`&length=`length`&height=`height`
    Then response code should be 200
    And response body should be valid xml

  Scenario: Generate an XML threat (depth attack) and reject it
    When I GET /xml?width=`width`&depth=15&length=`length`&height=`height`
    Then response code should be 500
    And response body should be valid json

  Scenario: Generate an XML threat (width attack) and reject it
    When I GET /xml?width=20&depth=`depth`&length=`length`&height=`height`
    Then response code should be 500
    And response body should be valid json

  Scenario: Generate an XML threat (length attack) and reject it
    When I GET /xml?width=`width`&depth=`depth`&length=10&height=`height`
    Then response code should be 500
    And response body should be valid json

  Scenario: Generate an XML threat (height attack) and reject it
    When I GET /xml?width=`width`&depth=`depth`&length=`length`&height=20
    Then response code should be 500
    And response body should be valid json