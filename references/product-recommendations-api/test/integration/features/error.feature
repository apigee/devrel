@error
Feature: API proxy error handling
    As API administrator
    I want to ensure invalid paths are caught
    So I can respond appropriately.

	@get-foo
    Scenario: Verify the Open API Spec is returned
        Given I set X-APIKey header to `clientId`
        When I GET /foo
        Then response code should not be 200
        And response header Content-Type should be application/json
