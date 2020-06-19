Feature:
  As an API Developer
  I want to get mock data
  So that I can independently build an API

  Scenario: Get Mock Value
    When I GET /mock/v1/dogs
    Then response code should be 200
    Then response body path $[0].name should be Max
