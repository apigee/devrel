Feature:
  As a developer
  I want to modernise my mainframe with APIs
  So that I can apply API management best practices

  Scenario: Successfully use Apigee OpenLegacy Kickstart
    Given I set request body to { "customerid": "0001" }
    When I POST /getcst?apikey=`apikey`
    Then response code should be 200
    And response body path $.status should be OK
    
  Scenario: Missing API Key
    Given I set request body to { "customerid": "0001" }
    When I POST /getcst
    Then response code should be 401
