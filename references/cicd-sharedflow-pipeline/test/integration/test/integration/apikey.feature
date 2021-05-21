Feature: Check if API is secured with API Key
	As an API user
	I want to make sure the API is protected by API Key
	So that the API is secured

	Scenario: Send request without API Key
	    When I GET /
	    And  response body should contain Unauthorized
	    And response code should be 401

	Scenario: Send request with dummy API Key
	    Given I set apikey header to dummy
	    When I GET /
	    And  response body should contain Unauthorized
	    And response code should be 401

	Scenario: Send request with correct API Key
	    Given I set apikey header to `APIKEY`
	    When I GET /
	    And response code should be 200
