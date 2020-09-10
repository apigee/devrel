Feature:
  As an API developer
  I want to be able to use mTLS
  So that I limit access to my backend to trusted sources

  Scenario: Request without client authentication
    When I GET /
    Then response code should be 400

  Scenario: Request without client authentication
    When I GET /?auth=true
    Then response code should be 200
