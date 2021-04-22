Feature:
  As an API developer
  I want to access FHIR resources
  So that I can connect to a FHIR Server

  Scenario: Get the server metadata
    When I GET /metadata
    Then response status code should be 200
    And response body path $.resourceType should be CapabilityStatement

  Scenario: Get Patient Information
    When I GET /Patient
    Then response status code should be 200
    And response body should contain generatePractitioner
