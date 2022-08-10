# Contributing

1. We welcome any Pull Requests that help the Apigee community. Our focus is:
    1. reference code that can be used by others to solve a specific problem
    1. labs that are intended to teach others about specific features
    1. tools that automate a specific task or improve productivity
1. Projects must not exclusively support products managed via [Apigee Edge Management APIs](https://cloud.google.com/apigee/docs/api-platform/get-started/compare-apigee-products) (api.enterprise.apigee.com) but can optionally support these platforms
1. Projects accepted to this repository should be considered a recommendable best practice by the field engineers, customers, community and product management
1. Projects should be small and simple
1. Projects should not duplicate an existing implementation within the [Apigee GitHub org](https://github.com/apigee). We should be building on top of previous ideas, rather than branching out and duplicate aspects of it
1. For very large pull requests (e.g. rewrite of a large portion or entire project), please first propose changes via a new GitHub issue and discuss with the community before raising the PR.
1. We follow the [Google Open Source Community Guidelines](https://opensource.google/conduct/)
1. We pride ourselves on the high quality of this repository. Therefore we ask
  each contribution to have accompanying tests with thorough coverage to help
  meet this goal (see [`PIPELINES.md`](./PIPELINES.md)).

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

- Linter [Mega Linter](https://megalinter.github.io)
- Apache 2.0 [License](https://opensource.google/docs/releasing/preparing/#license-file)
 checks
- All projects are listed in [CODEOWNERS](./CODEOWNERS) and [README](./README.md)
- Contributor License [Agreement](https://opensource.google/docs/cla/)
- In [Solidarity](https://developers.google.com/style/inclusive-documentation)
- [Pipelines](./PIPELINES.md)
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
  standards to tell the release automation which [SemVer](https://semver.org/)
  version increase is intended.
