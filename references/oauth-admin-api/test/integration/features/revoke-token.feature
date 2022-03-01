@TokenRevocation
Feature:
  As an oauth admin
  I want to use a token revocation service
  So that I can invalidate previously issued access tokens before their expiration

  Scenario: [Helper] Obtain OAuth Access Token
    Given I set form parameters to
      |parameter|value|
      |grant_type|client_credentials|
    And I have basic authentication credentials `clientId` and `clientSecret`
    When I POST to /oauth2/token
    Then response code should be 200
    And response body should be valid json
    And I store the value of body path $.access_token as accessToken in global scope
    And I store the value of body path $.application_name as appName in global scope

  Scenario: Revoke App token for invalid app id
    Given I set authorization header to "Bearer `accessToken`"
    And I set query parameters to
      |parameter|value|
      |app|something-unknown|
    When I POST to /oauth2/revoke
    Then response code should be 400

  Scenario: Revoke App token for missing enduser and app id
    Given I set authorization header to "Bearer `accessToken`"
    When I POST to /oauth2/revoke
    Then response code should be 400

  Scenario: Revoke App token for a valid app id
    Given I set authorization header to "Bearer `accessToken`"
    And I set query parameters to
      |parameter|value|
      |app|`appName`|
    When I POST to /oauth2/revoke
    Then response code should be 202