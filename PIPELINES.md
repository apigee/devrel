# Pipelines

Each project should have a `pipeline.sh` script that will be run nightly to
install and test your code and alert if there are regression failures.

## pipeline.sh

The `pipeline.sh` script:

- is run whenever a Pull Request changes that project
- is run for all projects each night
- is run on a private continuous integration server after an initial code
  review
- depends on external configuration parameters in the form of environment
  variables to let the pipeline target Apigee X and Edge organizations
- runs in a Docker container that you can see [here](./tools/pipeline-runner/Dockerfile)

  You can run a pipeline locally:

  ```sh
  docker run \
    -v $(pwd):/home \
    -e APIGEE_USER -e APIGEE_PASS -e APIGEE_ORG -e APIGEE_ENV \
    -e APIGEE_X_ORG -e APIGEE_X_ENV -e APIGEE_X_HOSTNAME \
    -v ~/.config:/root/.config \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -it ghcr.io/apigee/devrel-pipeline-runner:latest run-pipelines.sh references/js-callout
  ```

  Where:
  - The `APIGEE_` variables point to your Apigee instance
  - This repo is mounted in the home directory
  - (Required for X) mount your gcloud config folder
  - (Required for Docker-in-Docker pipelines) mount the docker socket
  - Specify a reference e.g. `references/js-callout` or omit to run everything

  Should you need to make changes to the pipeline runner, you can
  build your own image by running the following command and replacing
  the image reference above:

  ```sh
  docker build -t devrel-pipeline-runner:local ./tools/pipeline-runner
  ```

A simple example of a pipeline can be found [here](./references/js-callout/pipeline.sh)

### Environment Variables

Currently, pipelines tests can run against Apigee Edge or Apigee X. The
 following environment variables are available for this:

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

Static code checks such as [Mega Linter](https://megalinter.github.io/)
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
