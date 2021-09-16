# MockTarget
MockTarget to demonstrate Apigee CI/CD using GCP.

## Prerequisites
 * Apigee X or Apigee Hybrid org with an env called "eval"
 * GCS - create a bucket named MockTarget in the same region as your Apigee org
 * Update cloudbuild.yaml, cloudbuild-release.yaml and fill in your eval org in variable "_APIGEE_ORG" 
 * Update test/MockTargetEval.postman_environment.json with your eval org domain and IP

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
