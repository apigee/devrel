Feature:
  As an API Consumer
  I want to proxy a target endpoint using a Target Server
  So that I can control the endpoint

  Scenario: Successful @TargetPath@
    When I GET @TargetPath@
    Then response code should be 200
