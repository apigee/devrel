# Apigee CICD using Jenkins and Maven

## Goal

Rerference implementaton for a CICD pipeline for Apigee using [Jenkins](https://www.jenkins.io/) and the [Apigee Deploy Maven Plugin](https://github.com/apigee/apigee-deploy-maven-plugin).

The CICD pipeline includes:
*   Git branch dependent Apigee environment selection and proxy naming to allow deployment of feature branches as separate proxies in the same environment
*   Static code analysis using [eslint](https://eslint.org/)
*   Unit testing using [mocha](https://mochajs.org/)
*   Integration testing of the deployed proxy using [apickli](https://github.com/apickli/apickli)
*   Packaging and deployment of the API proxy bundle using [Apigee Deploy Maven Plugin](https://github.com/apigee/apigee-deploy-maven-plugin)

## Target Audience

*   API Engineers
*   Operations
*   Security

## Limitations & Requirements

*   The Authentication to the Apigee management API is done using OAuth2. If you require MFA, please see the [documentation](https://github.com/apigee/apigee-deploy-maven-plugin#oauth-and-two-factor-authentication) for the Maven deploy plugin on how to configure MFA for the build.


## Prerequisites

### Jenkins

The `jenkins` folder contains instructions on how to setup a dockerized Jenkins environment to run this the Jenkins pipeline in for the API proxy. You can either use the the included instructions to configure a Jenkins server or use your existing server.

#### Option A: Configure Jenkins Docker Container

See the instructions in [./jenkins/README.md](./jenkins/README.md)

#### Option B: Use an existing Jenkins Setup

If you already have a current (version 2.200+) Jenkins instance you can also use that one.

You are responsible to ensure you have the following plugins enabled:
*   [Multibranch Pipeline](https://plugins.jenkins.io/workflow-multibranch/)
*   [HTML Pubisher](https://plugins.jenkins.io/htmlpublisher/)
*   [Cucumber Reports](https://plugins.jenkins.io/cucumber-reports/)

### API Proxy

The folder `airports-cicd-v1` includes a simple API proxy bundle as well as the following resources:
*   [Jenkinsfile](./airports-cicd-v1/Jenkinsfile) to define a Jenkins multi-branch pipeline.
*   [Test Folder](./airports-cicd-v1/test) to hold the unit and integration tests.

## CI/CD Configuration Instructions

### Jenkins Configuration

Once Jenkins is configured as described above, you need to configure the following:


## Create a Multi-Branch Jenkins Job

Use the UI to configure the Jenkins Job for multibranch pipelines:

1.  Path to the Jenkinsfile e.g. `Jenkinsfile`
1.  Set the Git repo accordingly e.g. [Apigee Devrel](https://github.com/apigee/devrel)
1.  (Optional) Set the build trigger / polling frequency

## Run the pipeline

1.  Open the multi-branch pipeline you just created.
1.  Click `Scan Multibranch Pipeline Now` to detect branches with a Jenkinsfile.
1.  Explore the build(s) that get triggered.
1.  Explore the final build success.

## Promote to different stages and environments (feature/test/prod)

1.  Fork this repository and point your multi-branch jenkins pipeline to it.
1.  Create a new feature branch e.g. `feature/my-feature`
1.  Explore the newly created api-proxy in the test environment that corresponds to the feature branch
1.  Merge the feature branch into `master` and explore the promotion into test environment
1.  Merge the `master` branch into the branch `prod` and explore the promotion into prod environment
