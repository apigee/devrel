# Jenkins Example Setup

This document explains how to set up and configure a Jenkins CI server to run an Apigee deployment pipeline.

You can choose between two different setups:
*   `Jenkins Web`: Builds an image for running Jenkins with a web UI.
*   `Jenkinsfile Runner` Builds an ephemeral runtime for running a specific Jenkinsfile without having to configure the full UI. We use this version for our continuous testing in Apigee DevRel.

## Jenkins Web

Follow these instructions to build and run a fully configured Jenkins UI instance.

### Build

#### Option A: Local Build

```bash
docker build -f jenkins-web/Dockerfile -t apigee-cicd/jenkins:latest .
```

#### Option B: Cloud Build on GCP

```bash
PROJECT_ID=$(gcloud config get-value project)
gcloud builds submit --config ./jenkins-web/cloudbuild.yml
docker pull gcr.io/$PROJECT_ID/apigee-cicd/jenkins:latest
docker tag gcr.io/$PROJECT_ID/apigee-cicd/jenkins:latest apigee-cicd/jenkins:latest
```

### Run the Jenkins Container

Ensure you have your Apigee credentials set:

```bash
export APIGEE_USER=XXX
export APIGEE_PASS=XXX
export APIGEE_ORG=XXX
```

Add a password for the Jenkins admin user:

```bash
export JENKINS_ADMIN_PASS=password
```

And start the Docker container:

```bash
docker run \
  -p 8080:8080 \
  -p 5000:5000 \
  -e APIGEE_USER \
  -e APIGEE_PASS \
  -e APIGEE_ORG \
  -e JENKINS_ADMIN_PASS \
  apigee-cicd/jenkins:latest
```

After the initialization is completed, you can login with the Jenkins web UI `http://localhost:8080` using the `admin` user and the password you specified before.

## Jenkinsfile-Runner

Follow these instructions to build and run an ephemeral Jenkinsfile runtime.

### Build

#### Option A: Local Build

```bash
docker build -f jenkinsfile-runner/Dockerfile -t apigee-cicd/jenkinsfile-runner .
```

#### Option B: Cloud Build on GCP

```bash
PROJECT_ID=$(gcloud config get-value project)
gcloud builds submit --config ./jenkinsfile-runner/cloudbuild.yml
docker pull gcr.io/$PROJECT_ID/apigee-cicd/jenkinsfile-runner:latest
docker tag gcr.io/$PROJECT_ID/apigee-cicd/jenkinsfile-runner:latest apigee-cicd/jenkinsfile-runner:latest
```

### Example Run

```bash
docker run \
  -v ${PWD}/../airports-cicd-v1:/workspace \
  -e APIGEE_USER \
  -e APIGEE_PASS \
  -e APIGEE_ORG \
  -e GIT_BRANCH=travis \
  -e AUTHOR_EMAIL="cicd@apigee.google.com" \
  -it apigee-cicd/jenkinsfile-runner
```
