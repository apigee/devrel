# Sample Java Callout Project

This reference project provides a simple example of an API Proxy using a
Custom Java Callout.

In this example, the Java code is packaged as a jar, and as such has a separate
`pom.xml` file.

## Prerequisites

- Java [JDK](https://www.oracle.com/uk/java/technologies/javase-downloads.html)
  1.8+
- [Node JS](https://nodejs.org/) LTS or above
- Apigee Evaluation [Organization](https://login.apigee.com/sign__up)
- Apigee Dependencies downloaded to folder ./java-callout/apigee-lib
  - [expressions-1.0.0.jar](https://github.com/apigee/api-platform-samples/blob/master/doc-samples/java-properties/lib/expressions-1.0.0.jar)
  - [message-flow-1.0.0.jar](https://github.com/apigee/api-platform-samples/blob/master/doc-samples/java-properties/lib/message-flow-1.0.0.jar)

  ```sh
  LIB_FOLDER="./java-callout/apigee-lib"
  mkdir -p "./java-callout/apigee-lib"
  (cd $LIB_FOLDER && curl -O "https://raw.githubusercontent.com/apigee/api-platform-samples/master/doc-samples/java-properties/lib/message-flow-1.0.0.jar")
  (cd $LIB_FOLDER && curl -O "https://raw.githubusercontent.com/apigee/api-platform-samples/master/doc-samples/java-properties/lib/expressions-1.0.0.jar")
  ```

## Quick Start

```shell
export APIGEE_USER=xxx
export APIGEE_PASS=xxx
export APIGEE_ORG=xxx
mvn clean install -Ptest -ntp
```
