Feature:
  As a developer
  I want to generate a service callout from an OAS spec
  So that I can bootstrap my API proxy

  Scenario: I successfully convert the Petstore API Spec
    Given I set variable SPEC to test/features/fixtures/petstore.json
    And I set variable OPERATION to createPets
    When I successfully run bin/oas-to-am.sh | xmllint --format -
    Then on the result, I run diff - test/features/fixtures/expected.xml -q

