# Airports CI/CD V1 Proxy

This contains an example proxy for the CI/CD pipeline reference using Cloud Build
and Maven.

## Development

- Install dependencies:

  ```sh
  npm install
  ```

- Unit testing:

  ```sh
  npm run unit-test
  ```

- Integration testing against host `$APIGEE_ORG-$APIGEE_ENV.apigee.net` and
  default basepath `airports-cicd/v1`:

  ```sh
  TEST_HOST=$APIGEE_ORG-$APIGEE_ENV.apigee.net npm run integration-test
  ```

- Integration testing against feature branch deployment on
  `airports-cicd-feature-ABC/v1`:

  ``` sh
  TEST_HOST=$APIGEE_ORG-$APIGEE_ENV.apigee.net TEST_BASE_PATH='/ airports-cicd-feature-ABC/v1' npm run integration-test
  ```

## Run Cloud Build Deployment

### Apigee hybrid

Requires the Cloud Build API to be enabled and a Service Account with the
following roles (or a custom role with all required permissions):
  * Apigee API Admin
  * Apigee Environment Admin

```sh
gcloud services enable cloudbuild.googleapis.com
PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
CLOUD_BUILD_SA="$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/apigee.environmentAdmin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/apigee.apiAdmin"
```

Run the following command to trigger a cloud build manually:

```sh
gcloud builds submit --config=cloudbuild.yaml --substitutions=_API_VERSION=google,_DEPLOYMENT_ORG=$PROJECT_ID,_INT_TEST_HOST=api.my-host.example.com,_INT_TEST_BASE_PATH=/airports-cicd-experiment/v1,BRANCH_NAME=experiment
```

### Apigee SaaS

Requires the Cloud Build API to be enabled and a Service Account with the
following role:
  * Secret Manager Secret Accessor

```sh
gcloud services enable secretmanager.googleapis.com cloudbuild.googleapis.com

PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
CLOUD_BUILD_SA="$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/secretmanager.secretAccessor"
```

To pass the Apigee user and password securely into the Cloud Build pipeline you
have to add these two secrets to the cloud secret manager:
  * `apigee_cicd_user` that holds the user to use for the CI/CD account
  * `apigee_cicd_password` that holds the password for the CI/CD account

```sh
echo "$APIGEE_USER" | gcloud secrets create apigee_cicd_user --data-file=-
echo "$APIGEE_PASS" | gcloud secrets create apigee_cicd_password --data-file=-
```

Run the deployment (with a simulated git branch name)

```sh
gcloud builds submit --config=cloudbuild.yaml --substitutions=_API_VERSION=apigee,_INT_TEST_HOST=$APIGEE_ORG-$APIGEE_ENV.apigee.net,_INT_TEST_BASE_PATH=/airports-cicd-experiment/v1,_DEPLOYMENT_ORG=$APIGEE_ORG,BRANCH_NAME=experiment
```
