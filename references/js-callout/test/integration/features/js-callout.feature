Feature:
  As an API developer
  I want to hide sensitive data from the response body
  So that I expose only what is necessary for the clients

  Scenario: Setting headers in GET request
    When I GET /get
    Then response body should not contain X-Amzn-Trace.Id
