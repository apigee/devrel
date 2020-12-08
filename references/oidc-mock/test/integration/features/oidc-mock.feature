@AccessIdentityProvider
Feature:
  As a Client App 
  I want to get an access token from an identity provider
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
      | scope	    | openid email address    |
    When I POST to /v1/openid-connect/token
    Then response code should be 200
    And I store the value of body path $.access_token as userToken in global scope

  Scenario: Client App Accesses User Information
    Given I set Authorization header to Bearer `userToken`
    When I GET /v1/openid-connect/userinfo
    Then response code should be 200
    And response body path $.email should be (.+@example.com)

  Scenario: Client App Accesses Introspection Endpoint 
    Given I have basic authentication credentials `clientId` and `clientSecret`
    And I set form parameters to
      | parameter   | value                   |
      | token	    | `userToken`	      |
    When I POST to /v1/openid-connect/introspection
    Then response code should be 200
    And response body path $.active should be (true)

  Scenario: Client App Accesses JWKS Resource
    When I GET /v1/openid-connect/certs
    Then response code should be 200
    And response body path $.keys[0].alg should be (RS256)
    And response body path $.keys[0].n should be (.)
    And response body path $.keys[0].kid should be (oidcmock)
