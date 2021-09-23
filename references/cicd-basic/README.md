# CICD-basic 
An easy to follow tutorial on Integration Apigee into you Continuous Integration and Continuous Deployment pipeline in GCP. 

## Prerequisites
 1. Select an existing Apigee X or Apigee Hybrid org with an env called *eval* or signup for an Apigee trial.
 2. In GCS, create a bucket named *apigee-build* in the same region as your Apigee org
 3. In IAM, grant following roles to default Cloud Build service account *[project_number]@cloudbuild.gserviceaccount.com*
       *  Apigee API Admin
       *  Apigee Environment Admin
       *  Secret Manager Secret Accessor
 4. In Apigee console, create *MockProduct* for /mocktarget/v1 API
 5. In Apigee console, create developer app *MockTargetAppQA* for *MockProduct*
 5. In Cloud Secret Manager, store API Key from *MockTargetAppQA* as follows
     1. nonprod: mocktarget-apikey-nonprod-qa=APIkey
     2. prod: mocktarget-apikey-prod-qa=APIkey
 6. In a terminal, clone this repo and update cloudbuild.yaml, cloudbuild-release.yaml with your Apigee org details in *substitutions* section 
```yaml
      _APIGEE_ORG: your_apigee_org
      _APIGEE_RUNTIME_HOST: your_api_runtime_domain
``` 

## Usage

### Package, build, test, save artifact
```sh
gcloud builds submit --config=./cloudbuild.yaml
```

### Download artifact and deploy
```sh
gcloud builds submit --config=./cloudbuild-release.yaml \
                     --substitutions=_COMMIT_SHA=
```

## Cloud Build setup
Create Cloud Build triggers for testing in nonprod and release to prod based on git commits to git branches or git tags.
