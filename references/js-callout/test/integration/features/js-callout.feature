Feature:
  As an API developer
  I want to add additional data to the HTTP response
  So that I can forward relevant metadata to the clients

  Scenario: Setting headers in GET request
    When I GET /get
    Then response body should contain x-foo
