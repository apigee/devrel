@AuthorizeEndpointWithPKCE
Feature:
  As a Client App 
  I want to access the protected resource of an API
  So that I can retrieve different types of information

  Scenario: I should get an error if code_challenge is missing
    Given I navigate to the authorize page without a pkce code challenge
    Then I am redirected to the Client App
    Then I receive an invalid_request error
  
  Scenario: I should get an error if code_challenge_method is missing
    Given I navigate to the authorize page without a pkce code challenge method
    Then I am redirected to the Client App
    Then I receive an invalid_request error
  
  Scenario: I should get an error if code_challenge_method is invalid
    Given I navigate to the authorize page with an invalid pkce code challenge method
    Then I am redirected to the Client App
    Then I receive an invalid_request error
  
  Scenario: User Authorizes
    Given I navigate to the authorize page
    When I sign in and consent
    Then I am redirected to the Client App
    And I receive an auth code in a query param
    And I store the auth code in global scope
    And I store the state parameter in global scope
