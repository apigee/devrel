# CICD Pipeline for SharedFlows

This project contains a reference implementation for a CI/CD pipeline for
Apigee sharedflow using the [Apigee Deploy Maven
Plugin](https://github.com/apigee/apigee-deploy-maven-plugin).

## Pre-requisites

- Node.js (10.x or later)
- Maven (3.x or later)
- Java (8 or later)

## Execution

This example deploys the Sharedflow to Apigee. To test the sharedflow,
the test contains a simple proxy that calls this sharedflow and then executes
some tests to verify if the sharedflow works as expected.

### Apigee Edge

#### To deploy the sharedflow

```sh
mvn clean install -Papigeeapi -Dorg=${org} -Denv=${env} \
-Dusername=${username} -Dpassword=${password}
```

#### To test the sharedflow

```sh
mvn install -Papigeeapi -Dorg=${org} -Denv=${env} \
-Dusername=${username} -Dpassword=${password} -f test/integration/pom.xml
```

The above command will deploy a test proxy that calls the sharedflow,
configure API Product, Developer and an App. The plugin will then download
the app credentials and use that for running integration test cases

#### To delete the Test API Products, Developer and App

```sh
mvn apigee-config:apps apigee-config:apiproducts -Papigeeapi -Dorg=${org} -Denv=${env} \
-Dusername=${username} -Dpassword=${password} -Dapigee.config.options=delete \
-f test/integration/pom.xml
```

### Apigee X / hybrid

#### To deploy the sharedflow

```sh
mvn clean install -Pgoogleapi -Dorg=${org} -Denv=${env} -Dfile=${file}
```

#### To test the sharedflow

```sh
mvn install -Pgoogleapi -Dorg=${org} -Denv=${env} \
-Dfile=${file} -Dapi.northbound.domain=${api.northbound.domain} \
-f test/integration/pom.xml
```

The above command will deploy a test proxy that calls the sharedflow,
configure API Product, Developer and an App. The plugin will then download
the app credentials and use that for running integration test cases

#### To delete the Test API Products, Developer and App

```sh
mvn apigee-config:apps apigee-config:apiproducts -Pgoogleapi -Dorg=${org} -Denv=${env} \
-Dfile=${file} -Dapi.northbound.domain=${api.northbound.domain} -Dapigee.config.options=delete \
-f test/integration/pom.xml
```
