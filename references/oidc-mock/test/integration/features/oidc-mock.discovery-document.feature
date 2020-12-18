@DiscoveryDocumentEndpoint
Feature:
  As a Client App 
  I want to access the discovery document 
  So that I can discover response types, grant types and endpoint of an identity provider

  Scenario: Client App Accesses Discovery Document
    When I GET /.well-known/openid-configuration
    Then response code should be 200
    And response body path $.response_types_supported[0] should be code
    And response body path $.grant_types_supported[0] should be authorization_code
  
  Scenario: Client App uses a wrong URI to access Discovery Document
    When I GET /baduri/openid-configuration
    Then response code should be 404
    And response body should be valid json
    And response body path $.error should be not_found
