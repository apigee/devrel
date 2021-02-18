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

## Quick Start

```shell
export APIGEE_USER=xxx
export APIGEE_PASS=xxx
export APIGEE_ORG=xxx
mvn clean install -Ptest -ntp
```
