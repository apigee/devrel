# How to Contribute

We'd love to accept your patches and contributions to this project. There are
just a few small guidelines you need to follow.

1.  Sign a Contributor License Agreement (see below).
1.  Fork the repo, develop and test your changes. Here are some recommendations:
    1.  Go for a simple, minimalist, lean, [suckless](https://en.wikipedia.org/wiki/Suckless.org) implementation - solve the problem with no fanfare or bloat around it.
    1.  Go for ease of maintenance as the primary goal.
    1.  A bash of 10 lines is sometimes much better than an express app!
1.  Develop using the following guidelines to help expedite your review:
    1.  Ensure that your code adheres to the existing
        [style](https://google.github.io/styleguide).
    1.  Ensure that your code has an appropriate set of tests which all pass.
    1.  Ensure that your code has an accompanying README.md file. See
        [awesome-readme](https://github.com/matiassingers/awesome-readme) for
        good examples of high-quality READMEs. Please include the following
        information in your README:
        1.  What problem(s) does your solution solve.
        1.  What functionalities are implemented and instructions on how to use them.
    1.  Add a link to your contribution in the top-level
        [README](https://github.com/Apigee/DevRel/blob/master/README.md)
        (alpha-order).
    1.  Ensure that your submission does not include a LICENSE file. There's no
        need to include an additional license since all repository submissions
        are covered by the top-level Apache 2.0
        [license](https://github.com/Apigee/DevRel/blob/master/LICENSE).
    1.  Ensure all files copied or derived from a third party library are stored
        in the `/third_party` directory. Also ensure that every directory
        inside the third_party directory has a LICENSE file that contains the
        full license text and copyright notice for the library.
    1.  Ensure each file (that take the format of a source file and supports
        file comments) has license headers with an up-to-date copyright date
        attributed to `Google LLC`
        1.  For files in the third_party dir, leave the existing headers in
            place. If you've modified a file, append "Google LLC" to the
            copyright line.
        1.  For Google-authored source files, paste the Apache header text in
            the comments at the top. (If you're using different license,
            include the full text of that license.)
1.  Place an executable called `pipeline` on the root of your solution folder
    which builds, deploy and tests your solution. This file will be executed by
    our automation daily. Make sure that you use an appropriate
    [shebang](https://en.wikipedia.org/wiki/Shebang_(Unix)) if you want the automation
    to execute a text file. See
    [this example pipeline](https://github.com/apigee/DevRel/blob/master/demos/hello-world/pipeline)
    implementation.
1.  Submit a pull request.

## DevRel Automation

Apigee DevRel uses automation that runs daily to ensure all solutions build successfully with all tests passing. It is recommended for the contributors to run the same checks locally at least once before every pull request to ensure build won't fail in our automation.

We use docker to setup the environment to run the full pipeline so ensure you
have docker installed and configured on your development environment.

In order to run this process locally for your solution:

```
# build a docker image that will run the automation pipeline
npm run build-pipeline-runner

# run the pipeline for a single solution folder
npm run pipeline -- <path-to-your-solution-folder>
E.g. npm run pipeline -- ./demos/hello-world
```

In order to run the pipeline for all solutions within DevRel, execute the following commands:

```
# build a docker image that will run the automation pipeline
npm run build-pipeline-runner

# run the pipeline for all solution folders
npm run pipeline
```

Check out the
[Dockerfile](https://github.com/apigee/DevRel/blob/master/Dockerfile) to see how
the pipeline is implemented.

### Apigee Org Variables

If your solution contains any Apigee proxies, you are required to deploy them to an
Apigee org and run tests within your pipeline. This is to ensure that
your proxies can deploy without any failures and tests are passing.

In order to help with this, Apigee DevRel Automation will populate the following
environment variables which you can use in your deploy scripts:

| Variable    | Description                               |
| ---         | ---                                       |
| APIGEE_ORG  | The name of the Apigee organization       |
| APIGEE_ENV  | The name of the Apigee environment        |
| APIGEE_USER | The username of an admin user in this org |
| APIGEE_PASS | The password for the admin user           |

Please note that only `test` and `prod` environments are available. `test`
environment is the default value for `APIGEE_ENV`.

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

This project follows [Google's Open Source Community
Guidelines](https://opensource.google/conduct/).
