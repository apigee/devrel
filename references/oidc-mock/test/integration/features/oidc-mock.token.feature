@TokenIssuance
Feature:
    As a Client App 
    I want to get an access_token and id_token from an identity provider
    So that I can retrieve different types of information

    Scenario: Generate Access Token
        Given I have basic authentication credentials `clientId` and `clientSecret`
        And I set form parameters to 
        | parameter   | value		            |
        | grant_type  | authorization_code      |
        | code        | dummy-code-xyz          |
        | redirect_uri| https://httpbin.org/get |
        |	state	  | `state`		            |
        | scope	      | openid email address    |
        When I POST to /token
        Then response code should be 200
        And response body path $.access_token should be (dummy-access_token.+)
        And I store the value of body path $.access_token as userToken in global scope

    Scenario: I should get an error if client_id and/or secret are wrong
        Given I have basic authentication credentials xxx and yyy
        And I set form parameters to 
        | parameter   | value		            |
        | grant_type  | authorization_code      |
        | code        | dummy-code-xyz          |
        | redirect_uri| https://httpbin.org/get |
        | state       | `state` 	            |
        | scope	      | openid email address    |
        When I POST to /token
        Then response code should be 401
        And response body path $.error should be invalid_client

    Scenario: I should get an error if redirect_uri is missing
        Given I have basic authentication credentials `clientId` and `clientSecret`
        And I set form parameters to 
        | parameter   | value		            |
        | grant_type  | authorization_code      |
        | code        | dummy-code-xyz          |
        | state       | `state`		            |
        | scope	      | openid email address    |
        When I POST to /token
        Then response code should be 400
        And response body path $.error should be invalid_request

    Scenario: I should get an error if grant_type is not authorization_code
        Given I have basic authentication credentials `clientId` and `clientSecret`
        And I set form parameters to 
        | parameter   | value		            |
        | grant_type  | xxx                     |
        | code        | dummy-code-xyz          |
        | redirect_uri| https://httpbin.org/get |
        | state       | `state`		            |
        | scope	      | openid email address    |
        When I POST to /token
        Then response code should be 400
        And response body path $.error should be unsupported_grant_type

    Scenario: I should get an error if code is not posted
        Given I have basic authentication credentials `clientId` and `clientSecret`
        And I set form parameters to 
        | parameter   | value		            |
        | grant_type  | authorization_code      |
        | redirect_uri| https://httpbin.org/get |
        | state       | `state`		            |
        | scope	      | openid email address    |
        When I POST to /token
        Then response code should be 400
        And response body path $.error should be invalid_grant
    
    Scenario: I should get an error if scope is not posted
        Given I have basic authentication credentials `clientId` and `clientSecret`
        And I set form parameters to 
        | parameter   | value		            |
        | grant_type  | authorization_code      |
        | code        | dummy-code-xyz          |
        | redirect_uri| https://httpbin.org/get |
        | state       | `state`		            |
        When I POST to /token
        Then response code should be 400
        And response body path $.error should be invalid_request
