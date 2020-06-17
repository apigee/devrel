Feature:
  As an API Consumer
  I want consistent error messages
  So that I can easily debug issues

Scenario: Unauthorized
  When I GET /protected
  Then response code should be 401
  And response body path $.code should be 401.99
  And response body path $.message should be Unauthorized - Token Invalid
  And response body path $.info should be https://developers.example.com
  

