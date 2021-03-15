# Pipelines

Each project should have a `pipeline.sh` script that will be run nightly to
install and test your code and alert if there are regression failures.

## pipeline.sh

The `pipeline.sh` script:

- is run whenever a Pull Request changes that projects
- is run for all projects each night
- is run on a private continuous integration server after an initial code
 review, to reduce the risk of exposing secrets
- has access to an Apigee Edge organization, accessed with the variables
 below.
- runs in a Docker container that you can see [here](./tools/pipeline-runner/Dockerfile).
 You can run a pipeline locally e.g. `npm run pipeline -- references/js-callout`

A simple example of a pipeline can be found [here](./references/js-callout/pipeline.sh)

### Variables

Currently an Apigee Edge (4G) is used to run the tests. The following variables
 are available for this.

| Variable    | Description                               |
| ----------- | ----------------------------------------- |
| APIGEE_ORG  | The name of the Apigee organization       |
| APIGEE_ENV  | The name of the Apigee environment        |
| APIGEE_USER | The username of an admin user in this org |
| APIGEE_PASS | The password for the admin user           |

## Static Checks

Static code checks such as [Super Linter](https://github.com/github/super-linter)
 and [In Solidarity](https://github.com/apps/in-solidarity) are triggered
 automatically and do not need to be included in your pipeline script. We
 recommend you allow these to run in GitHub as it is simpler than running
 locally. We don't mind if the Pull Request fails at first due to these checks!

## GitHub Pages

If you would like to generate static HTML as part of your project, you can
create a `generate-docs.sh` script. This script should generate static HTML in
 the subdirectory `./generated/docs`, after which it will be deployed to GitHub
 pages. You can see an example using CodeLabs [here](./labs/best-practices-hackathon/generate-docs.sh).
