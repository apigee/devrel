Feature:
  As an API developer
  I want to access FHIR resources
  So that I can connect to a FHIR Server

  Scenario: Get the server metadata
    When I GET /metadata
    Then response code should be 200
    And response body path $.resourceType should be CapabilityStatement

  Scenario: Get Patient Information
    When I GET /Patient/nl-core-patient-03
    Then response code should be 200
    And response body should contain generalPractitioner

  Scenario: Get AllergyIntolerance from multiple sources
    When I GET /AllergyIntolerance/zib-allergyintolerance-01
    Then response code should be 200
    And response body path $.patient.display should be Mediated Display Name
