Feature: Greeting

  @story-1
  Rule: Calling /hello with a name returns a greeting addressed to that name

    Scenario: A caller provides a name
      Given the greeter service is running
      When a caller requests "/hello?name=Ada" from greeter
      Then the response is a JSON greeting addressed to "Ada"

  @story-2
  Rule: Calling /hello without a name still succeeds with a generic greeting

    Scenario: A caller omits the name
      Given the greeter service is running
      When a caller requests "/hello" from greeter with no name parameter
      Then the response is a JSON generic greeting

    Scenario: A caller provides an empty name
      Given the greeter service is running
      When a caller requests "/hello?name=" from greeter
      Then the response is a JSON generic greeting
