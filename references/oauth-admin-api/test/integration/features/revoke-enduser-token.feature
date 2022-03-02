@TokenRevocationEndUser
Feature:
  As an oauth admin
  I want to use a token revocation service based on enduser ids
  So that I can invalidate previously issued access tokens before their expiration

  Scenario: [Helper] Obtain OAuth Access Token
    Given I set form parameters to
      |parameter|value|
      |grant_type|client_credentials|
    And I set query parameters to
      |parameter|value|
      |app_enduser|bob|
    And I have basic authentication credentials `clientId` and `clientSecret`
    When I POST to /oauth2/token
    Then response code should be 200
    And response body should be valid json
    And I store the value of body path $.access_token as accessToken in global scope

  Scenario: Revoke App token for a valid enduser id
    Given I set authorization header to "Bearer `accessToken`"
    And I set query parameters to
      |parameter|value|
      |enduser|bob|
    When I POST to /oauth2/revoke
    Then response code should be 202