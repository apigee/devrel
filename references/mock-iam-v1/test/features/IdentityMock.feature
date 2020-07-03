Feature:
  As an API Developer
  I want to host an Identity Mock in Apigee
  So that I can developer a proxy without any backend dependencies

@Debug
  Scenario: Generate Admin Access Token
    Given I set form parameters to
      | parameter  | value        |
      | grant_type | password     |
      | client_id  | admin-cli    |
      | username   | admin        |
      | password   | Password123  |
    When I POST to `oidcPrefix`/token
    Then response code should be 200 
#   And response body should be valid according to schema file ./schemas/adminToken.json
    And response body path $.expires_in should be 60
    And response body path $.refresh_expires_in should be 1800
    And I store the value of body path $.access_token as admin-token in global scope

  Scenario: Create Client
    Given I set Content-Type header to application/json
    And I set Authorization header to Bearer `admin-token`
    And I pipe contents of file ./fixtures/client.json to body
    When I POST to `adminPrefix`/clients
    Then response code should be 201

  Scenario: Get Client
    Given I set Authorization header to Bearer `admin-token`
    When I GET `adminPrefix`/clients?clientId=seans-client
    Then response code should be 200
#    And response body should be valid according to schema file ./schemas/getClients.json
    And response body path $.[0].clientId should be seans-client
    And response body path $.[0].rootUrl should be https://httpbin.org/get
    And response body path $.[0].clientAuthenticatorType should be client-secret
    And response body path $.[0].redirectUris[0] should be https://httpbin.org/get
    And response body path $.[0].protocol should be openid-connect
    And I store the value of body path $.[0].id as client-id in global scope

  Scenario: Get Client Secret
    Given I set Authorization header to Bearer `admin-token`
    When I GET `adminPrefix`/clients/`client-id`/client-secret
    Then response code should be 200
    #And response body should be valid according to schema file ./schemas/getClientSecret.json
    And response body path $.type should be secret
    And response body path $.value should be (.+)
    And I store the value of body path $.value as client-secret in global scope
    
  Scenario: Generate Access Token - Client Credentials
    Given I have basic authentication credentials seans-client and `client-secret`
    And I set form parameters to
      | parameter  | value              |
      | grant_type | client_credentials |
    When I POST to `oidcPrefix`/token
    Then response code should be 200
    And response body should be valid according to schema file ./schemas/clientCredentialsToken.json

  Scenario: Create User
    Given I set Content-Type header to application/json
    And I set Authorization header to Bearer `admin-token`
    And I pipe contents of file ./fixtures/user.json to body
    When I POST to `adminPrefix`/users
    Then response code should be 201

  Scenario: Get Users
    Given I set Authorization header to Bearer `admin-token`
    When I GET `adminPrefix`/users?username=someone
    Then response code should be 200
#    And response body should be valid according to schema file ./schemas/getUsers.json
    And response body path $.[0].username should be someone
    And I store the value of body path $.[0].id as user-id in global scope
 
  Scenario: Set User Password
    Given I set Content-Type header to application/json
    And I set Authorization header to Bearer `admin-token`
    And I pipe contents of file ./fixtures/pass.json to body
    When I PUT `adminPrefix`/users/`user-id`/reset-password
    Then response code should be 204

  Scenario: Generate Access Token - Password Grant
    Given I have basic authentication credentials seans-client and `client-secret`
    And I set form parameters to
      | parameter  | value              |
      | grant_type | password           |
      | username   | someone            |
      | password   | password           |
    When I POST to `oidcPrefix`/token
    Then response code should be 200
    And response body should be valid json
#    And response body should be valid according to schema file ./schemas/passwordToken.json
    And response body path $.expires_in should be 60
    And response body path $.refresh_expires_in should be 1800

  Scenario: Get Authorization Code
    When I set query parameters to 
    | parameter     | value       |
    | client_id     | seans-client|
    | response_type | code        |
    | state         | abc         |
    When I GET `oidcPrefix`/auth
    Then response code should be 302
    And response header Location should be https://httpbin.org/get\?code=(.+)\&state=(.+)
    And I store the value of response query param code as auth-code in global scope

  Scenario: Generate Access Token - Authorization Code Grant
    Given I have basic authentication credentials seans-client and `client-secret`
    And I set form parameters to
      | parameter  | value              |
      | grant_type | authorization_code |
      | code       | `auth-code`        |
    When I POST to `oidcPrefix`/token
    Then response code should be 200
#    And response body should be valid according to schema file ./schemas/authCodeToken.json
    And response body path $.expires_in should be 60
    And response body path $.refresh_expires_in should be 1800
    And response body path $.scope should be profile email

