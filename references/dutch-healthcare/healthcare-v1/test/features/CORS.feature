Feature:
  Given I am a browser
  When I consume an API
  Then I receive CORS headers

  Scenario: Successfully obtain CORS headers on Preflight call
    When I request OPTIONS for /
    Then response header Access-Control-Allow-Origin should exist
    And response header Access-Control-Allow-Headers should exist
    And response header Access-Control-Max-Age should exist
    And response header Access-Control-Allow-Methods should exist

  Scenario: Successfully obtain CORS headers on API call
    When I GET /ping
    Then response header Access-Control-Allow-Origin should exist
    And response header Access-Control-Allow-Headers should exist
    And response header Access-Control-Max-Age should exist
    And response header Access-Control-Allow-Methods should exist
