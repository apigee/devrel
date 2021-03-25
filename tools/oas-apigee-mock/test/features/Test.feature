Feature:
  As an API Developer
  I want to get mock data
  So that I can independently build an API

  Scenario: Get all orders
    When I GET /orders
    Then response code should be 200

  Scenario: Get order by id
    When I GET /orders/123
    Then response code should be 200

  Scenario: Update an order by id
    When I PUT /orders/123
    Then response code should be 200

  Scenario: Create an order
    When I POST to /orders/123
    Then response code should be 201