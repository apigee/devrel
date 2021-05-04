Feature:
  As an API Developer
  I want to get mock data
  So that I can independently build an API

  Scenario: Get all orders
    Given I set x-apikey header to `apikey`
    When I GET /oas-apigee-mock-orders-apikey-header/orders
    Then response code should be 200
    And response body should be valid json
    And response body path $.orders should be of type array
    And response body path $.orders[0].orderId should be 61knu8gol56

  Scenario: Get order by id
    Given I set x-apikey header to `apikey`
    When I GET /oas-apigee-mock-orders-apikey-header/orders/123
    Then response code should be 200
    And response body should be valid json
    And response body path $.orderId should be 61knu8gol56

  Scenario: Update an order by id
    Given I set x-apikey header to `apikey`
    When I PUT /oas-apigee-mock-orders-apikey-header/orders/123
    Then response code should be 200

  Scenario: Create an order
    Given I set x-apikey header to `apikey`
    When I POST to /oas-apigee-mock-orders-apikey-header/orders/123
    Then response code should be 201
    And response body should be valid json
    And response body path $.orderId should be 61knu8gol56

  Scenario: Request fails with no api key present
    When I POST to /oas-apigee-mock-orders-apikey-header/orders/123
    Then response code should be 401

  Scenario: Request does not fail when OPTIONS is requested
    When I request OPTIONS for /oas-apigee-mock-orders-apikey-header/orders/123
    Then response code should be 200

  Scenario: A bad request should fail OAS validation and return a 400 status code
      Given I set x-apikey header to `apikey`
      When I GET /oas-apigee-mock-orders-apikey-header/orders/123/123
      Then response code should be 400