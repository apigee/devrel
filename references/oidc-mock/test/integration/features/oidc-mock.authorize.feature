@InitiateAuthentication
Feature:
    As a Client App 
    I want to get an authorization code from an identity provider
    So that I can retrieve an access_token and id_token

    Scenario: User authorizes client app to access protected resources
        Given I navigate to the authorize page
        When I sign in and consent
        Then I am redirected to the Client App
        And I receive an auth code in a query param
        And I store the auth code in global scope
        And I store the state parameter in global scope

    Scenario: I should get an error if client_id is not provided
        When I GET /authorize?redirect_uri=https://httpbin.org/get&response_type=code&state=12345&scope=openid%20email
        Then response code should be 400
    
    Scenario: I should get an error if client_id is wrong
        When I GET /authorize?client_id=xxx&redirect_uri=https://httpbin.org/get&response_type=code&state=12345&scope=openid%20email
        Then response code should be 401
    
    Scenario: I should get an error if response_type is missing or wrong
        Given I navigate to the authorize page with an invalid response type
        Then I am redirected to the Client App
        Then I receive an unsupported_response_type error

    Scenario: I should get an error if scope is missing
        Given I navigate to the authorize page without a scope parameter
        Then I am redirected to the Client App
        Then I receive an invalid_request error
    
    Scenario: I should get an error if state is missing
        Given I navigate to the authorize page without a state parameter
        Then I am redirected to the Client App
        Then I receive an invalid_request error

    Scenario: I should get an error if redirect_uri is missing
        When I GET /authorize?client_id=dummy-client_id-123&response_type=code&scope=openid%20email
        Then response code should be 400

    Scenario: I should get an error if redirect_uri is invalid
        When I GET /authorize?client_id=dummy-client_id-123&response_type=code&scope=openid%20email&redirect_uri=https://example.com/invalid
        Then response code should be 400
