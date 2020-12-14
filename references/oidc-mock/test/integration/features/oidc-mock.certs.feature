@CertsEndpoint
Feature:
  As a Client App 
  I want to get JWKS keys 
  So that I can validate JWT token (id_token)

  Scenario: Client App Accesses JWKS Resource
    When I GET /certs
    Then response code should be 200
    And response body path $.keys[0].alg should be RS256
    And response body path $.keys[0].n should be (.)
    And response body path $.keys[0].kid should be oidcmock
  
  Scenario: Client App uses a wrong URI to access JWKS Resource
    When I GET /badcerts
    Then response code should be 404
    And response body should be valid json
    And response body path $.error should be not_found
