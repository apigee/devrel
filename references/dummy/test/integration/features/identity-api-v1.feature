@AccessProtectedResource
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

  Scenario: Generate Access Token
    Given I have basic authentication credentials `clientId` and `clientSecret`
    And I set form parameters to 
      | parameter   | value		      |
      | grant_type  | authorization_code      |
      | code        | `authCode`              |
      | redirect_uri| https://httpbin.org/get |
      |	state	    | `state`		      |	
    When I POST to /v1/oauth20/token
    Then response code should be 200
    And I store the value of body path $.access_token as userToken in global scope

  Scenario: Client App Accesses Protected Resource
    Given I set Authorization header to Bearer `userToken`
    When I GET /v1/oauth20/protected
    Then response code should be 200
    And response body path $.response.status should be (ok)
    And response body path $.response.message should be (.+)
    And response body path $.response.user.email should be (.+@example.com)

  Scenario: Client App Accesses Protected Resource without a Valid Access Token
    Given I set Authorization header to Bearer 'xxx-invalid-toen-xxx'
    When I GET /v1/oauth20/protected
    Then response code should be 401
    And response body should be valid json

  Scenario: Client App Accesses a Resource that is Not Found
    When I GET /v1/oauth20/notfound
    Then response code should be 404
    And response body should be valid json
