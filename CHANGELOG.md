# Changelog

## [1.5.0](https://github.com/apigee/devrel/compare/v1.4.0...v1.5.0) (2022-12-06)


### Features

* add styling to kvm notes ([6c928da](https://github.com/apigee/devrel/commit/6c928da8ee8f516d57f152dc6a5ffc22aa14eb3a))
* adding google authentication to templating ([802e7c4](https://github.com/apigee/devrel/commit/802e7c41660627ec343950afe63908ef8109f92c))
* adding only caches listing capability for apigee x reporting ([b35ad02](https://github.com/apigee/devrel/commit/b35ad0267b9ff8d69d5dec42bf58b297d63e1f62))
* allow for wildcard path matching in endpoints importer ([d66d197](https://github.com/apigee/devrel/commit/d66d1975a5ced754dde00f1571633c0a50f6d2ac))
* cloud endpoints importer ([89a0258](https://github.com/apigee/devrel/commit/89a0258e578a901d90ba3ab3cd14713a731ebeef))
* OAS client authentication ([50b489e](https://github.com/apigee/devrel/commit/50b489e51f4bc625cd662a0dd8d174d6806743ad))
* root-level target backends ([22b4f52](https://github.com/apigee/devrel/commit/22b4f52b31be9054cc907667cf55e94fd5b994c8))


### Bug Fixes

* api products table formating ([657708a](https://github.com/apigee/devrel/commit/657708a0c58a52f1804ded7e24659367fe185cf7))
* change yq version in pipeline-runner ([c8e7b80](https://github.com/apigee/devrel/commit/c8e7b80720512ccfe910f1cb470689cb3d32fd8a))
* jq error for non existing files ([49a2379](https://github.com/apigee/devrel/commit/49a2379446f82bc44c07888c8e0ff9577ff98070))
* jq error in apiproducts.sh ([dd17a62](https://github.com/apigee/devrel/commit/dd17a62cca27d2487e24ac4b2d9892bb6de10a30))
* jq error on developers.sh ([1b2fdf7](https://github.com/apigee/devrel/commit/1b2fdf713d237a1bc775da864f10e2c039204dca))
* refactor code ([852a2e9](https://github.com/apigee/devrel/commit/852a2e9e4e2e2426613bc977d6a5587416af5240))

## [1.4.0](https://github.com/apigee/devrel/compare/v1.3.0...v1.4.0) (2022-10-31)


### Features

* bump hybrid quickstart to 1.8.2 ([8b0e3ad](https://github.com/apigee/devrel/commit/8b0e3adb3c44534d7847fa989e02ecd1f5d24424))

## [1.3.0](https://github.com/apigee/devrel/compare/v1.2.0...v1.3.0) (2022-09-30)


### Features

* bump hybrid quickstart to 1.8.1 ([407ffe4](https://github.com/apigee/devrel/commit/407ffe4ef576e1a3ca26b6800ba67a6bd5944f9f))

## [1.2.0](https://github.com/apigee/devrel/compare/v1.1.2...v1.2.0) (2022-09-28)


### Features

* reporting enhancements for OPDK ([ad3113a](https://github.com/apigee/devrel/commit/ad3113a0a69c9de73104bde19e45465bcb59567d))

## [1.1.2](https://github.com/apigee/devrel/compare/v1.1.1...v1.1.2) (2022-09-22)


### Bug Fixes

* improved error handling on x trial provisioning script ([c9bbafa](https://github.com/apigee/devrel/commit/c9bbafac7d15fafd73b6017ec7754f5c19c6b93c))

## [1.1.1](https://github.com/apigee/devrel/compare/v1.1.0...v1.1.1) (2022-09-16)


### Bug Fixes

* bump all jenkins plugin versions ([26fc286](https://github.com/apigee/devrel/commit/26fc2863dc5253e99467bb2d984981d88c7bbd58))
* resolved jenkins cicd example dependency conflict ([6a2d1e9](https://github.com/apigee/devrel/commit/6a2d1e936742144175e8aa5365560685f5411609))

## [1.1.0](https://github.com/apigee/devrel/compare/v1.0.1...v1.1.0) (2022-09-01)


### Features

* bump hybrid quickstart to 1.8 with Apigee ingress ([7c4ffe9](https://github.com/apigee/devrel/commit/7c4ffe956fbf4df3afa4ca8d05ce9f188885f5d5))


### Bug Fixes

* add retry for wildcard gateway install ([d10cd87](https://github.com/apigee/devrel/commit/d10cd879515f280f752e88644872e5878cdb2ddf))

## [1.0.1](https://github.com/apigee/devrel/compare/v1.0.0...v1.0.1) (2022-08-26)


### Bug Fixes

* typo in Sackmesser Deploy ([864c7e3](https://github.com/apigee/devrel/commit/864c7e3cc2ffdc0f869ebc115a35ffc505c9d8e1))

## 1.0.0 (2022-08-19)


### ⚠ BREAKING CHANGES

* releases for Apigee DevRel

### Features

* add mvn config plugin to cicd pipeline example ([6ed918d](https://github.com/apigee/devrel/commit/6ed918d071053eafc465b50850e6562564761bbb))
* add support for opdk ([8f7f16b](https://github.com/apigee/devrel/commit/8f7f16b0b2184574f1c1040571678aaebb05bcb9))


### Bug Fixes

* add the legacy ingress gateway flag to asmcli ([cf549fc](https://github.com/apigee/devrel/commit/cf549fce4cdc49a1dc8e98fc7583104bc7de733a))
* bump hybrid from 1.7.2 to 1.7.3 ([58c974b](https://github.com/apigee/devrel/commit/58c974bccd45c5ac8160b036301d720243e1e614))
* Fix jenkins plugin version resulution for matrix-project ([73bc9f8](https://github.com/apigee/devrel/commit/73bc9f81b1a3e2a8c915dc57a5750fcf6be5c05b))
* increase timeout for waiting for setup job ([7749b66](https://github.com/apigee/devrel/commit/7749b66caa78a96db0f52ce0225c88aa1313d3cb))
* plugin dependency for jenkins example ([82901e6](https://github.com/apigee/devrel/commit/82901e6e237cce3e0f531aeceb3edbd98289c404))


### Miscellaneous Chores

* releases for Apigee DevRel ([77c3e84](https://github.com/apigee/devrel/commit/77c3e845e6aafbfed8403ddcf8dc567b4b8bc4c0))
