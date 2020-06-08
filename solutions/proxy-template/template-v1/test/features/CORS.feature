Feature:
  Given I am Web Developer
  When I consume an API from my own domain
  Then I shouldn't receive any CORS errors

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

