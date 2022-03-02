@TokenRevocationGeneral
Feature:
  As an oauth admin
  I want to use a token revocation service
  So that I can invalidate previously issued access tokens before their expiration

  Scenario: Revoke App token without an access token
    Given I set query parameters to
      |parameter|value|
      |app|something-reasonable|
    When I POST to /oauth2/revoke
    Then response code should be 401

  Scenario: Revoke App token with an invalid token
    Given I set authorization header to "Bearer eyJwbGFjZWhvbGRlciI6ICJpbG92ZWFwaXMxMjMifQo="
    And I set query parameters to
      |parameter|value|
      |app|something-reasonable|
    When I POST to /oauth2/revoke
    Then response code should be 401

  Scenario: 404 on undefined flows
    When I GET /
    Then response code should be 404