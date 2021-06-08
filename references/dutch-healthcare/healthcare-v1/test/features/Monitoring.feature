Feature:
  As an API Operator
  I want to call the monitoring endpoints on an API
  So that I can understand an APIs deployment status

  Scenario: Successful /ping
    When I GET /ping
    Then response code should be 200
