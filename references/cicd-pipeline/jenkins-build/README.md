# Jenkins Example Setup

This document explains how to build and configure a Jenkins CI server container
image to run an Apigee deployment pipeline.

You can choose between two different setups:

- `Jenkins Web`: Builds an image for running Jenkins with a web UI.
- `Jenkinsfile Runner` Builds an ephemeral runtime for running a specific
  Jenkinsfile without having to configure the full UI. We use this version for
  our continuous testing in Apigee DevRel.

## Jenkins Web

Follow these instructions to build and run a fully configured Jenkins UI
instance.

### Build

#### Option A: Use a pre-built image

```sh
docker pull ghcr.io/apigee/devrel-jenkins:latest
docker tag ghcr.io/apigee/devrel-jenkins:latest apigee/devrel-jenkins:latest
```

#### Option B: Local Build

```sh
docker build -f jenkins-web/Dockerfile -t apigee/devrel-jenkins:latest .
```

#### Option C: Cloud Build on GCP

```sh
PROJECT_ID=<my-project>
gcloud builds submit --config ./jenkins-web/cloudbuild.yml
docker pull gcr.io/$PROJECT_ID/apigee/devrel-jenkins:latest
docker tag gcr.io/$PROJECT_ID/apigee/devrel-jenkins:latest apigee/devrel-jenkins:latest
```

### Run the Jenkins Container

In this section we describe how to setup Jenkins on either a GCP VM or
locally via Docker.

#### Option A Run Jenkins on a GCP Compute Engine VM

To run Jenkins on a Compute Engine VM first make sure you have the Container
Image in GCR. If you have not used Cloud Build to build your Image then push it
to GCR like so:

```sh
docker tag apigee/devrel-jenkins:latest gcr.io/$PROJECT_ID/apigee/devrel-jenkins:latest
docker push gcr.io/$PROJECT_ID/apigee/devrel-jenkins:latest
```

If you are building for Apigee X or hybrid you should create a dedicated service
account for your Jenkins VM that has all required permission to deploy to Apigee.

```sh
JENKINS_SA_NAME="jenkins"
JENKINS_SA_EMAIL="$JENKINS_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"
gcloud iam service-accounts create "$JENKINS_SA_NAME" --project "$PROJECT_ID"

# Permissions to deploy to Apigee
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$JENKINS_SA_EMAIL" \
  --role="roles/apigee.environmentAdmin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$JENKINS_SA_EMAIL" \
  --role="roles/apigee.apiAdmin"

# Permission to pull the jenkins image from GCR
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$JENKINS_SA_EMAIL" \
  --role="roles/storage.objectViewer"

```

To restrict access to only your machine set the firewall to only allow your
external IP (Otherwise replace it with `--source-ranges='0.0.0.0/0'`).

```sh
gcloud compute firewall-rules create allow-me-jenkins --allow=tcp:8080 \
  --description="Allow only my IP to access jenkins" \
  --direction=INGRESS --target-tags=jenkins --source-ranges="$(curl ipecho.net/plain)/32" \
  --project $PROJECT_ID
```

##### Apigee X/hybrid Credentials on GCE

To start your jenkins with credentials for Apigee X/hybrid run the following
command:

```sh
CONTAINER_ENVS="JENKINS_ADMIN_PASS=password"
CONTAINER_ENVS+=",API_VERSION=google"
CONTAINER_ENVS+=",APIGEE_ORG=$APIGEE_X_ORG"
CONTAINER_ENVS+=",APIGEE_TEST_ENV=test1"
CONTAINER_ENVS+=",APIGEE_PROD_ENV=prod1"
CONTAINER_ENVS+=",TEST_HOST=$APIGEE_X_HOSTNAME"

gcloud compute instances create-with-container jenkins --tags jenkins \
  --container-image gcr.io/$PROJECT_ID/apigee/devrel-jenkins:latest \
  --container-env "$CONTAINER_ENVS" \
  --machine-type e2-standard-2 \
  --service-account "$JENKINS_SA_EMAIL"  --scopes cloud-platform

echo "Starting Jenkins Container. Once Jenkins is ready you can visit: http://$(gcloud compute instances describe jenkins --format json | jq -r ".networkInterfaces[0].accessConfigs[0].natIP"):8080"
```

##### Apigee Edge Credentials on GCE

To start your jenkins with credentials for Apigee Edge run the following command:

```sh

CONTAINER_ENVS="JENKINS_ADMIN_PASS=password"
CONTAINER_ENVS+=",API_VERSION=apigee"
CONTAINER_ENVS+=",APIGEE_ORG=$APIGEE_ORG"
CONTAINER_ENVS+=",APIGEE_TEST_ENV=test"
CONTAINER_ENVS+=",APIGEE_PROD_ENV=prod"
CONTAINER_ENVS+=",APIGEE_USER=$APIGEE_USER"
CONTAINER_ENVS+=",APIGEE_PASS=$APIGEE_PASS"
CONTAINER_ENVS+=",TEST_HOST=$APIGEE_ORG-$APIGEE_ENV.apigee.net"

gcloud compute instances create-with-container jenkins --tags jenkins \
  --container-image gcr.io/$PROJECT_ID/apigee/devrel-jenkins:latest \
  --container-env "$CONTAINER_ENVS" \
  --machine-type e2-standard-2 \
  --service-account "$JENKINS_SA_EMAIL" --scopes cloud-platform

echo "Starting Jenkins Container. Once Jenkins is ready you can visit: http://$(gcloud compute instances describe jenkins --format json | jq -r ".networkInterfaces[0].accessConfigs[0].natIP"):8080"
```

#### Option B Run Jenkins Locally

You can also run a local Docker image as follows:

##### Apigee Edge in local Docker

```sh
docker run \
  -p 8080:8080 \
  -p 5000:5000 \
  -e APIGEE_USER \
  -e APIGEE_PASS \
  -e APIGEE_ORG \
  -e APIGEE_TEST_ENV="test" \
  -e APIGEE_PROD_ENV="prod" \
  -e TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net" \
  -e API_VERSION="apigee" \
  -e JENKINS_ADMIN_PASS="password" \
  apigee/devrel-jenkins:latest
```

##### Apigee X/hybrid in local Docker

*Note:* for long running jenkins deployments condider mounting the gcloud
service account credentials from the host filesystem instead of passing
the access token via environment variables.

```sh
docker run \
  -p 8080:8080 \
  -p 5000:5000 \
  -e APIGEE_TOKEN="$(gcloud auth print-access-token)" \
  -e APIGEE_ORG \
  -e APIGEE_TEST_ENV="test1" \
  -e APIGEE_PROD_ENV="prod1" \
  -e TEST_HOST="api.example.apigee.com" \
  -e API_VERSION="google" \
  -e JENKINS_ADMIN_PASS="password" \
  apigee/devrel-jenkins:latest
```

After the initialization is completed, you can login with the Jenkins web UI
`http://localhost:8080` using the `admin` user and the password you specified
before.

## Jenkinsfile-Runner

Follow these instructions to build and run an ephemeral Jenkinsfile runtime.
This is maninly inteded for CICD of the pipeline itself.

### Build

#### Option A: Use a pre-built image

```sh
docker pull ghcr.io/danistrebel/devrel/jenkinsfile-runner:latest
docker tag ghcr.io/danistrebel/devrel/jenkinsfile-runner:latest apigee/devrel-jenkinsfile-runner:latest
```

#### Option B: Local Build

```sh
docker build -f jenkinsfile-runner/Dockerfile -t apigee/devrel-jenkinsfile-runner:latest
```

#### Option C: Cloud Build on GCP

```sh
PROJECT_ID=$(gcloud config get-value project)
gcloud builds submit --config ./jenkinsfile-runner/cloudbuild.yml
docker pull gcr.io/$PROJECT_ID/apigee/devrel-jenkinsfile-runner:latest
docker tag gcr.io/$PROJECT_ID/apigee/devrel-jenkinsfile-runner:latest apigee/devrel-jenkinsfile-runner:latest
```

### Example Run

See [pipeline.sh](../pipeline.sh) at the root of this reference.
