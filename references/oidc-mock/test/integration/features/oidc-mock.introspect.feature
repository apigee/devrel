@IntrospectionEndpoint
Feature:
    As a Client App 
    I want ot validate an access_token using the Introspection
    endpoint exposed by an identity provider

    Scenario: Client App Accesses Introspection Endpoint 
        Given I have basic authentication credentials `clientId` and `clientSecret`
        And I set form parameters to
        | parameter   | value                   |
        | token	      | dummy-access_token-xyz  |
        When I POST to /introspect
        Then response code should be 200
        And response body path $.active should be true

    Scenario: I should get an error if client_id and/or secret are wrong
        Given I have basic authentication credentials xxx and yyy
        And I set form parameters to
        | parameter   | value                   |
        | token	      | dummy-access_token-xyz  |
        When I POST to /introspect
        Then response code should be 401
        And response body path $.error should be invalid_client
    
    Scenario: I should get an error if access_token is invalid
        Given I have basic authentication credentials `clientId` and `clientSecret`
        And I set form parameters to
        | parameter   | value                   |
        | token	      | xxx                     |
        When I POST to /introspect
        Then response code should be 400
        And response body path $.error should be invalid_grant

    Scenario: I should get an error if access_token is not posted
        Given I have basic authentication credentials `clientId` and `clientSecret`
        And I set form parameters to
        | parameter   | value                   |
        When I POST to /introspect
        Then response code should be 400
        And response body path $.error should be invalid_request

