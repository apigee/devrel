@UserInfoEndpoint
Feature:
  As a Client App 
  I want to get user information (userinfo) from an identity provider

  Scenario: Client App Accesses User Information
    Given I set Authorization header to Bearer dummy-access_token-xyz
    When I GET /userinfo
    Then response code should be 200
    And response body path $.email should be (.+@example.com)
  
  Scenario: Client App Accesses User Information with an invalid Access Token
    Given I set Authorization header to Bearer xxx
    When I GET /userinfo
    Then response code should be 400
    And response body path $.error should be invalid_grant

  Scenario: Client App Accesses User Information without Access Token
    When I GET /userinfo
    Then response code should be 400
    And response body path $.error should be invalid_request
