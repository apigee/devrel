# Pipeline Runner

The pipeline runner provides the runtime execution context and orchestration
for running the pipelines of the individual Apigee DevRel projects.

For instructions on how to use the pipeline runner for DevRel pipelines
please see the [PIPELINES.md](../../PIPELINES.md) in the repo root.

## Contributing

If you want to run the pipeline runner in your own project then you need to
run the `gcp-setup.sh` script to create the required secrets in Cloud Secret
manager and give the Cloud Build service account the permissions to run it.

```sh
GITHUB_TOKEN="my token goes here"
APIGEE_USER="Apigee Edge User Email"
APIGEE_PASS="Apigee Edge password"

./gcp-setup.sh
```

You can then run the pipeline runner as a cloud build job like follows:

```sh
gcloud builds submit ../.. --substitutions=_CLEAN_ORG=false,_CI_PROJECT=references/my-reference,..
```




