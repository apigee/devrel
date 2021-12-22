# Contributing

- We welcome any Pull Requests that help the Apigee community. Our focus is:
  - reference code that can be used by others to solve a specific problem
  - labs that are intended to teach others about specific features
  - tools that automate a specific task or improve productivity
- Projects should be small and simple. A 10 line bash script is often easier to
 understand and maintain than a full NodeJS app!
- We follow the [Google Open Source Community Guidelines](https://opensource.google/conduct/)
- We pride ourselves on the high quality of this repository. Therefore we ask
  each contribution to have accompanying tests with thorough coverage to help
  meet this goal.

## Quickstart

- [Fork](https://docs.github.com/en/github/getting-started-with-github/fork-a-repo)
 the repository and make your contribution - please don't make changes to
 multiple projects in the same Pull Request!
- Ensure that your project has a [`pipeline.sh`](./PIPELINES.md) in the root of
 your project - see [here](./PIPELINES.md) for more
- Put the [Apache 2.0](https://opensource.google/docs/releasing/preparing/#Apache-header)
 license header in your source files (you might [automate](https://github.com/google/addlicense)
 this!)
- New projects, need a line in the [CODEOWNERS](./CODEOWNERS) file to declare [ownership](https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/about-code-owners)
- Create a [Pull Request](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request)
 with a description of your contribution
- At this stage, CI will run the below Pull Request Checks and we will do code
 reviews
- Once any issues found are resolved, your change will be merged!

## Pull Request Checks

- GitHub [Super Linter](https://github.com/github/super-linter)
- Apache 2.0 [License](https://opensource.google/docs/releasing/preparing/#license-file)
 checks
- All projects are listed in [CODEOWNERS](./CODEOWNERS) and [README](./README.md)
- Contributor License [Agreement](https://opensource.google/docs/cla/)
- In [Solidarity](https://developers.google.com/style/inclusive-documentation)
- [Pipelines](./PIPELINES.md)
