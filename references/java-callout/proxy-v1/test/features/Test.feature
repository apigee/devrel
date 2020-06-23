Feature:
  As an API Developer
  I want to test my code
  So that I can have confidence in its quality

  Scenario: Successful Request
    When I GET /get
    Then response code should be 200
    And response body path $.headers.X-Debug should be true
