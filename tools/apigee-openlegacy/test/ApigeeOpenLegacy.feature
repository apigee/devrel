Feature:
  As a developer
  I want to modernise my mainframe with APIs
  So that I can apply API management best practices

  Scenario: Successfully use Apigee OpenLegacy Kickstart
    Given I have deployed the Apigee OpenLegacy Kickstart
    And I set X-API-Key header to `apikey`
    And I set request body to { "customerid": "0001" }
    When I POST /getcst
    Then response code should be 200
    And response body path $.status should be OK
    
  Scenario: Invalid credentials
    Given I have deployed the Apigee OpenLegacy Kickstart
    And I set X-API-Key header to incorrect
    And I set request body to { "customerid": "0001" }
    When I POST /getcst
    Then response code should be 401
    
