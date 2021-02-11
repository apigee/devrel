# How to Contribute

We'd love to accept your patches and contributions to this project. There are
just a few small guidelines you need to follow.

1. Sign a Contributor License Agreement (see below).
2. Fork the repo, develop and test your changes. Here are some recommendations:
    1. Go for a simple, minimalist, lean,
        [suckless](https://en.wikipedia.org/wiki/Suckless.org) implementation -
        solve the problem with no fanfare or bloat around it.
    2. Go for ease of maintenance as the primary goal.
    3. A bash of 10 lines is sometimes much better than an express app!
    4. Pay attention to portability, i.e. if your solution can run in a docker
        container, on Apigee, node js, java, etc. then it is portable. If it is
        windows only or depends on specific Linux tools/libraries that can't be
        containerised, then it is not portable - therefore should be avoided.
3. Develop using the following guidelines to help expedite your review:
    1. Ensure that your code adheres to the existing
        [style](https://google.github.io/styleguide).
    2. Ensure that your code has an appropriate set of tests which all pass (see
        next Step).
    3. Ensure that your code has an accompanying README.md file. See
        [awesome-readme](https://github.com/matiassingers/awesome-readme) for
        good examples of high-quality READMEs. Please include the following
        information in your README:
        1. What problem(s) does your solution solve.
        2. What functionalities are implemented and instructions on how to use
            them.
    4. Add a link to your contribution in the top-level
        [README](https://github.com/Apigee/DevRel/blob/main/README.md)
        (alpha-order).
    5. Ensure that your submission does not include a LICENSE file. There's no
        need to include an additional license since all repository submissions
        are covered by the top-level Apache 2.0
        [license](https://github.com/Apigee/DevRel/blob/main/LICENSE).
    6. Ensure all files copied or derived from a third party library are stored
        in the `/third_party` directory. Also ensure that every directory inside
        the third_party directory has a LICENSE file that contains the full
        license text and copyright notice for the library.
    7. Ensure each file (that take the format of a source file and supports
        file comments) has license headers with an up-to-date copyright date
        attributed to `Google LLC`
        1. For files in the third_party dir, leave the existing headers in
            place. If you've modified a file, append "Google LLC" to the
            copyright line.
        2. For Google-authored source files, paste the Apache header text in
            the comments at the top. (If you're using different license, include
            the full text of that license.)
4. Place an executable called `pipeline.sh` on the root of your solution folder
    which builds, deploy and tests your solution. This file will be executed by
    our automation daily. Make sure that you use an appropriate
    [shebang](<https://en.wikipedia.org/wiki/Shebang_(Unix)>) if you want the
    automation to execute a text file. See [this example
    pipeline](https://github.com/apigee/DevRel/blob/main/references/js-callout/pipeline.sh)
    implementation.
5. Submit a pull request.

## DevRel Automation

Apigee DevRel uses automation that runs daily to ensure all solutions build
successfully with all tests passing. Additionally we apply static code analysis
to enforce a consistent coding style.It is recommended for the contributors to
run the same checks locally at least once before every pull request to ensure
the build won't fail in our automation.

We use docker to setup the environment to run the full pipeline so ensure you
have docker installed and configured on your development environment.

```sh
docker version
```

### Static Code Analysis via GitHub action

We use the [GitHub Super-Linter](https://github.com/github/super-linter)
collection to lint the entire DevRel repository. The Super-Linter image is quite
big (>>1GB) in size and therefore we suggest you to
[enable](https://docs.github.com/en/github/administering-a-repository/disabling-or-limiting-github-actions-for-a-repository)
GitHub actions on your fork and run the linter workflow automatically on every
push.

### Static Code Analysis locally

Using the DevRel linter image you can check for:

- License Files
- README Completeness

```sh
docker build -t apigee/devrel-linter ./tools/pipeline-linter
docker run --rm -v $(pwd):/home apigee/devrel-linter check-license.sh
docker run --rm -v $(pwd):/home apigee/devrel-linter check-readme.sh
```

The GitHub Super-Linter can be run via (note that locally all validators need to
be enabled explicitly):

```sh
docker run -e RUN_LOCAL=true \
  -e VALIDATE_BASH=true \
  -e VALIDATE_DOCKERFILE_HADOLINT=true \
  -e VALIDATE_JAVA=true \
  -e VALIDATE_JSON=true \
  -e VALIDATE_MARKDOWN=true \
  -e VALIDATE_VALIDATE_JAVASCRIPT_ES=true \
  -e VALIDATE_XML=true \
  -e VALIDATE_YAML=true \
  -e LOG_LEVEL=WARN \
  -v $(pwd):/tmp/lint \
  github/super-linter:v3
```

### Run Pipeline Tests

If your solution contains any Apigee proxies, you are required to deploy them
to an Apigee org and run tests within your pipeline. This is to ensure that
your proxies can deploy without any failures and tests are passing.

In order to help with this, Apigee DevRel Automation will populate the following
environment variables which you can use in your deploy scripts:

| Variable    | Description                               |
| ----------- | ----------------------------------------- |
| APIGEE_ORG  | The name of the Apigee organization       |
| APIGEE_ENV  | The name of the Apigee environment        |
| APIGEE_USER | The username of an admin user in this org |
| APIGEE_PASS | The password for the admin user           |

Please note that only `test` and `prod` environments are available. `test`
environment is the default value for `APIGEE_ENV`.

In order to run the pipeline locally for your solution run:

```sh
# Build the docker image for the pipeline runner
docker build -t apigee/devrel-pipeline ./tools/pipeline-runner

# Build a specific solution folder (./references/js-callout)
docker run \
 -e APIGEE_USER \
 -e APIGEE_PASS \
 -e APIGEE_ORG \
 -e APIGEE_ENV \
 -v $(pwd):/home \
 -v /var/run/docker.sock:/var/run/docker.sock \
 apigee/devrel-pipeline  run-pipelines.sh ./references/js-callout

# Or omit the path to the solution folder to run all DevRel pipelines
docker run \
 -e APIGEE_USER \
 -e APIGEE_PASS \
 -e APIGEE_ORG \
 -e APIGEE_ENV \
 -v $(pwd):/home \
 -v /var/run/docker.sock:/var/run/docker.sock \
 apigee/devrel-pipeline  run-pipelines.sh
```

Check out the [Dockerfile](https://github.com/apigee/devrel/blob/main/tools/pipeline-runner/Dockerfile)
to see how the pipeline is implemented.

## Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License
Agreement (CLA). You (or your employer) retain the copyright to your
contribution; this simply gives us permission to use and redistribute your
contributions as part of the project. Head over to
<https://cla.developers.google.com/> to see your current agreements on file or
to sign a new one.

You generally only need to submit a CLA once, so if you've already submitted
one (even if it was for a different project), you probably don't need to do it
again.

## Code reviews

All submissions, including submissions by project members, require review. We
use GitHub pull requests for this purpose. Consult [GitHub
Help](https://help.github.com/articles/about-pull-requests/) for more
information on using pull requests.

## Community Guidelines

This project follows
[Google's Open Source Community Guidelines](https://opensource.google/conduct/).
