# CICD-basic 
Sample repo to demonstrate Apigee Continuous Integration and Continuous Deployment using GCP services.

## Prerequisites
 * Apigee X or Apigee Hybrid org with an env called "eval"
 * GCS - create a bucket named MockTarget in the same region as your Apigee org
 * Grant Apigee API Admin, Apigee Environment Admin roles to default Cloud Build service account [project_number]@cloudbuild.gserviceaccount.com
 * Update cloudbuild.yaml, cloudbuild-release.yaml and fill in your Apigee org details in variables ```
      _APIGEE_ORG,
      _APIGEE_RUNTIME_HOST: your_api_runtime_domain
      _APIGEE_RUNTIME_IP: your_api_runtime_ip_if_needed
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
