Feature: Airport by IATA code
  As an API consumer
  I want to find popular airports by IATA code
  So that know the airport behind the code.

  Scenario: I should be able to identify an airport by its IATA code
    When I GET /airports/FRA
    Then response code should be 200
    And response body path $.airport should be Germany Frankfurt Airport

  Scenario: I should receive a 404 error for non-existing codes
    When I GET /airports/XYZ
    Then response code should be 404
