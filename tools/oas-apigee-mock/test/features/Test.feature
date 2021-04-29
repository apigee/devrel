Feature:
  As an API Developer
  I want to get mock data
  So that I can independently build an API

  Scenario: Get all orders
    Given I set x-apikey header to `apikey`
    When I GET /orders?apikey=`apikey`
    Then response code should be 200
    And response body should be valid json
    And response body path $.orders should be of type array
    And response body path $.orders[0].orderId should be 61knu8gol56

  Scenario: Get order by id
    Given I set x-apikey header to `apikey`
    When I GET /orders/123?apikey=`apikey`
    Then response code should be 200
    And response body should be valid json
    And response body path $.orderId should be 61knu8gol56

  Scenario: Update an order by id
    Given I set x-apikey header to `apikey`
    When I PUT /orders/123?apikey=`apikey`
    Then response code should be 200

  Scenario: Create an order
    Given I set x-apikey header to `apikey`
    When I POST to /orders/123?apikey=`apikey`
    Then response code should be 201
    And response body should be valid json
    And response body path $.orderId should be 61knu8gol56