@TokenEndpointWithPKCE
Feature:
  As a Client App 
  I want to access the protected resource of an API
  So that I can retrieve different types of information

  Scenario: User Authorizes
    Given I navigate to the authorize page
    When I sign in and consent
    Then I am redirected to the Client App
    And I receive an auth code in a query param
    And I store the auth code in global scope
    And I store the state parameter in global scope

  Scenario: I should get an error if code_verifier is wrong or missing
    Given I have basic authentication credentials `clientId` and `clientSecret`
    And I set form parameters to 
      | parameter   | value		      |
      | grant_type  | authorization_code      |
      | code        | `authCode`              |
      | redirect_uri| https://httpbin.org/get |
      | code_verifier| xxx |
    When I POST to /token
    Then response code should be 400
    And response body path $.error should be invalid_grant
