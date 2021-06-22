# Pipelines

Each project should have a `pipeline.sh` script that will be run nightly to
install and test your code and alert if there are regression failures.

## pipeline.sh

The `pipeline.sh` script:

- is run whenever a Pull Request changes that project
- is run for all projects each night
- is run on a private continuous integration server after an initial code
 review
- has access to an Apigee Edge organization, accessed with the variables
 below.
- runs in a Docker container that you can see [here](./tools/pipeline-runner/Dockerfile).
 You can run a pipeline locally e.g. `npm run pipeline -- references/js-callout`

A simple example of a pipeline can be found [here](./references/js-callout/pipeline.sh)

### Variables

Currently, pipelines tests can run against Apigee Edge or Apigee X. The
 following variables are available for this:

| Variable          | Description                                           |
| ----------------- | ----------------------------------------------------- |
| APIGEE_ORG        | The name of the Apigee Edge organization              |
| APIGEE_ENV        | The name of the Apigee Edge environment               |
| APIGEE_USER       | The username of an admin user in this Apigee Edge org |
| APIGEE_PASS       | The password of the user above                        |
| APIGEE_X_ORG      | The name of the Apigee X organization                 |
| APIGEE_X_ENV      | The name of the Apigee X environment                  |
| APIGEE_X_HOSTNAME | The hostname of the corresponding Apigee X env group  |

The pipeline context also has the `gcloud` context of a serviceaccount user
 that is an Apigee Administrator for the `APIGEE_X_ORG` Apigee organization.

## Static Checks

Static code checks such as [Super Linter](https://github.com/github/super-linter)
 and [In Solidarity](https://github.com/apps/in-solidarity) are part of the
 linter workflow. They do not need to be included in your pipeline script. We
 recommend you allow the DevRel [workflows](.github/workflows) to automatically
 run on your fork as this is simpler than running locally. In case the workflows
 are disabled, you can manually enable them again as described [here](https://docs.github.com/en/actions/managing-workflow-runs/disabling-and-enabling-a-workflow).
 We don't mind if the Pull Request fails at first due to these checks!

## GitHub Pages

If you would like to generate static HTML as part of your project, you can
create a `generate-docs.sh` script. This script should generate static HTML in
 the subdirectory `./generated/docs`, which is deployed to GitHub
 pages. You can see an example using CodeLabs [here](./labs/best-practices-hackathon/generate-docs.sh).
