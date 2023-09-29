Feature:
    As a Client App 
    I want to access the jwks and jwt endpoints functionality
    So that I can validate JWT token signature path

    Scenario: Validate jwks endpoint response
        Given I clear request
        When I GET /vault-facade/jwks
        Then response body should be valid json
        And response body path $.keys[0].crv should be P-256
        And response body path $.keys[0].x should be i5_DX1VZnVW7WTHk8tlHntfPASgmblQWSfTC9orCHJk
        And response body path $.keys[0].y should be qaYrjldDYeCLM5ruVU8i0SkE73yTcs-c3dUCeWmivU0
        And I store JWKS in global scope

    Scenario: Perform login via vault server
        Given I clear request
        And I set form parameters to
          | parameter  | value |
          | username   | user  |
          | password   | pass  |
        When I POST to /vault-facade/login
        Then response body should be valid json
        And I store the value of body path $.jwt-token as jwt in scenario scope
        And I decode JWT token value of scenario variable jwt as json in scenario scope

        And scenario variable json path $.iss should be ^https://35-201-121-246.nip.io$
        And scenario variable json path $.aud should be ^urn://c60511c0-12a2-473c-80fd-42528eb65a6a$
        # And I store the raw value https://35-201-121-246.nip.io as issuer in scenario scope
        # And I store the raw value urn://c60511c0-12a2-473c-80fd-42528eb65a6a as audience in scenario scope
        # And value of scenario variable jwt is valid JWT token
