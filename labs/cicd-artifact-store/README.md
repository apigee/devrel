# CICD-artifact-store

An easy to follow tutorial on Integrating Apigee into you Continuous Integration
 and Continuous Deployment pipeline in GCP.

**Note** This is a sample Apigee API project for use with GCP Cloud Solution
 *Integrating Apigee into your CI/CD cycle*. The instructions below are a
 simplified form of the tutorial covered in the solution.

## Prerequisites

 1. Select an existing Apigee X or hybrid org. Signup for an Apigee trial
  otherwise.
 2. In GCS, create a bucket in the same region as your Apigee org
 3. In IAM, grant following roles to default Cloud Build service account
  *[project_number]@cloudbuild.gserviceaccount.com*
       * Apigee API Admin
       * Apigee Environment Admin
       * Secret Manager Secret Accessor

## Usage

### Continuous Integration

 1. In Apigee console, create API product *MockProductDev* for API MockTarget
  and path /*
 2. In Apigee console, create developer *mocktargetqa@example.com*
 3. In Apigee console, create developer app *MockTargetAppQA* for *MockProduct*
 4. In Cloud Secret Manager, store API Key from *MockTargetAppQA* as follows
     1. Name=mocktarget-apikey-nonprod-qa
     2. Secret Value=[APIkey]
 5. In a terminal, clone this repo and update cloudbuild.yaml with your nonprod
 Apigee org or eval org details in *substitutions* section

    ```yaml
      _API_PROJECT: MockTarget
      _APIGEE_ORG: your_apigee_org
      _APIGEE_ENV: your_apigee_env_or_eval
      _APIGEE_RUNTIME_HOST: your_api_runtime_domain
      _APIGEE_BUILD_BUCKET: your_apigee_build_bucket
      ```

 6. In cloudshell, set GCP project config and run following

    ```sh
      gcloud builds submit --config=./cloudbuild.yaml
    ```

### Continuous Deployment with the pre-built artifact

 1. In Apigee console, create API product *MockProduct* for API MockTarget and
 path /*
 2. In Apigee console, create developer *mocktargetqa@example.com*
 3. In Apigee console, create developer app *MockTargetAppProdValidate* for
 *MockProduct*
 4. In Cloud Secret Manager, store API Key from *MockTargetAppProdValidate*
 as follows
     1. Name=mocktarget-apikey-prod-validate
     2. Secret Value=[APIkey]
 5. Update cloudbuild-release.yaml with your prod Apigee org or eval org details
  in *substitutions* section

      ```yaml
      _API_PROJECT: MockTarget
      _APIGEE_ORG: your_apigee_org
      _APIGEE_ENV: your_apigee_env_or_eval
      _APIGEE_RUNTIME_HOST: your_api_runtime_domain
      _APIGEE_BUILD_BUCKET: your_apigee_build_bucket
      ```

 6. In cloudshell, set GCP project config and run following

      ```sh
      gcloud builds submit --config=./cloudbuild-release.yaml \
                     --substitutions=_COMMIT_SHA=
      ```

## Cleanup

Delete GCP project to cleanup the CI, CD setup.
