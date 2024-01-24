# Changelog

## [1.16.0](https://github.com/apigee/devrel/compare/v1.15.1...v1.16.0) (2024-01-24)


### Features

* added run_parallel functions and logger for logging ([75ad51c](https://github.com/apigee/devrel/commit/75ad51c6c24c1fb8d669c72e87e99c2ce458ad78))
* added support for multiple proxy split ([2e30f5e](https://github.com/apigee/devrel/commit/2e30f5e2dac846b9dd001b3470da6d8b6de152ad))
* moved proxy bundle ([7c50710](https://github.com/apigee/devrel/commit/7c50710e679f13e3850dcb3957f88f3527367f3a))
* request payload converted to json & added json threat protection policy ([4bf4115](https://github.com/apigee/devrel/commit/4bf41157e659bcee0525e4a7ea49120167f31940))


### Bug Fixes

* added venv in pipeline.sh ([1db14cc](https://github.com/apigee/devrel/commit/1db14cc9f33fa94d500f96ea44c8f111d09fc3e0))
* added virtualenv to pipeline.sh ([a9ccfe8](https://github.com/apigee/devrel/commit/a9ccfe8339ecdde042a83a83761e1a4bcb6a201d))
* deleted jar files and updated dependencies ([5b5b4e5](https://github.com/apigee/devrel/commit/5b5b4e5212cb8a6bddd98494227b9b6bde2df9e9))
* fixed _cached_hosts issue ([0131a34](https://github.com/apigee/devrel/commit/0131a3446db32c334a77e471d5b2e3d6b303170e))
* fixed the target proxy Apigee type ([3b0dcc5](https://github.com/apigee/devrel/commit/3b0dcc5b3a5751a048537a0d2830724afc028127))
* removed csv headers from read rows ([83f4c98](https://github.com/apigee/devrel/commit/83f4c9865ee8ce496251d47a967229503f798791))
* updated library to gson ([4f0be35](https://github.com/apigee/devrel/commit/4f0be35687e5bdb89ab6e5f3f4043dd5345cd9c5))

## [1.15.1](https://github.com/apigee/devrel/compare/v1.15.0...v1.15.1) (2023-10-18)


### Bug Fixes

* change policy name for consistency ([31e3895](https://github.com/apigee/devrel/commit/31e3895f26041a4f3465ec7426838e94c52cdfc1))
* failing nightly because of jenkins version incompatibility ([d0ffaf1](https://github.com/apigee/devrel/commit/d0ffaf1d27ad0eee6981abb77b3b1c2ffa028bad))
* fix javax-mail-api jenksin pugin version ([adcbd19](https://github.com/apigee/devrel/commit/adcbd195535026ee768757911a14939d86cbbcb6))
* modification after review of the reference ([1815507](https://github.com/apigee/devrel/commit/18155077fbd5316a18ac6e2f9a67952239f7c527))
* rename flow callout policies for consistency ([5eabb2b](https://github.com/apigee/devrel/commit/5eabb2bf1bc85f3060a1a3e4e07abb9aa0a5c25f))

## [1.15.0](https://github.com/apigee/devrel/compare/v1.14.0...v1.15.0) (2023-09-25)


### Features

* updated gitingore ([a5c11b2](https://github.com/apigee/devrel/commit/a5c11b23f01531dbc6e44f3a74b935d014bba268))


### Bug Fixes

* added minor fixes to api re-deployment ([ef438a2](https://github.com/apigee/devrel/commit/ef438a21f762f5f60e61ae4e46e4bac9af6c6526))

## [1.14.0](https://github.com/apigee/devrel/compare/v1.13.0...v1.14.0) (2023-09-20)


### Features

* added javacallout build to pipeline ([4590268](https://github.com/apigee/devrel/commit/4590268294aa7057fdd73244168c1f8f40010a7e))
* added the java-callout resource for target server validator ([143d27d](https://github.com/apigee/devrel/commit/143d27dc89e8b1ea635037196992d809eeed64f0))
* Added wrappers for target-server-validator ([da88426](https://github.com/apigee/devrel/commit/da8842641e32ebd0896e6bbeaff7710f1ae1fb0b))
* disabled mypy check ([ec60898](https://github.com/apigee/devrel/commit/ec6089814159e5f427aa5b75b9b9958afdcc5475))
* renamed wrappers ([4f6b06f](https://github.com/apigee/devrel/commit/4f6b06f6befe2796439a494403fb696e51c0c4de))
* updated in-solidarity.yml ([a83d4b0](https://github.com/apigee/devrel/commit/a83d4b018fcdb2fa71945e68e811c6d4967e420b))


### Bug Fixes

* addressed PR comments ([2d9387a](https://github.com/apigee/devrel/commit/2d9387af1f71b67b16e3c3aa8cd9301c22510ec3))
* Fixed CODEOWNERS file ([733a807](https://github.com/apigee/devrel/commit/733a807788c39677bf93f83d204521c4f584fffc))
* fixed CODEOWNERS, Readme ([18dfdb6](https://github.com/apigee/devrel/commit/18dfdb688f5749d1200afb051e09807d6d08a355))
* fixed java , python lint issues ([541877d](https://github.com/apigee/devrel/commit/541877dd4555f6b3566ae92a5c882a76c9d1766d))
* fixed policy naming & gitignore ([a56f446](https://github.com/apigee/devrel/commit/a56f446be3e740dec9b26d74966c653946ba9993))
* fixed PR comments ([8efa176](https://github.com/apigee/devrel/commit/8efa176bae176173f7d239939b2c3ceb554df17d))
* fixed pyline issues ([6d17716](https://github.com/apigee/devrel/commit/6d177168406a4a3e573301d329b0e11102e6af57))
* fixed pylint errors ([f05d807](https://github.com/apigee/devrel/commit/f05d807f532782c221e295a768e7a3b79219ee42))
* only try to delete untagged images ([38754e0](https://github.com/apigee/devrel/commit/38754e0c38f26509da42635b9802dcbbc3788d43))

## [1.13.0](https://github.com/apigee/devrel/compare/v1.12.0...v1.13.0) (2023-08-17)


### Features

* added missing licenses ([cf6d1ff](https://github.com/apigee/devrel/commit/cf6d1ff5cdb940de93b9fa9c7a97aaaaacd3dffa))
* added pip package install to pipeline-runner ([06fd5fa](https://github.com/apigee/devrel/commit/06fd5fa70278c2b20c1defb6240389aa0811fcc0))
* Added proxy-endpoint-unifier source ([d9489f2](https://github.com/apigee/devrel/commit/d9489f281a150604a2ebff532e7517e6fa6491e1))
* added support for PostClientFlow ([d80c5b4](https://github.com/apigee/devrel/commit/d80c5b4b7e255ae7f0bba5d7221fa0f5c72495ab))
* added test scripts for proxy-endpoint-unifier ([740316e](https://github.com/apigee/devrel/commit/740316e0c2a9413a47484a18c3a0d9c0fcd343a8))
* added zip packaged to pipeline runner ([af3e94e](https://github.com/apigee/devrel/commit/af3e94ecb7a5c3851e478c0099c5a48d69c2c2dd))
* addressed flake8 for main proxy-endpoint-unifier wrapper ([18badee](https://github.com/apigee/devrel/commit/18badeef1adad545e94bec8374cd22ca554990a9))
* addressed flake8 for utils proxy-endpoint-unifier wrapper ([b812452](https://github.com/apigee/devrel/commit/b81245213b2653b7595652dfa79326e9d96f0355))
* addressed flake8 for xorhybrid proxy-endpoint-unifier wrapper ([7ccef07](https://github.com/apigee/devrel/commit/7ccef07a097041fc323388433dce7f8abca32a8a))
* fixed shell lint and updated README.md ([f3ff9a0](https://github.com/apigee/devrel/commit/f3ff9a01f28e9c015b16da09df61f98bb9b0f127))
* modified pipeline.sh & README ([fd3ba09](https://github.com/apigee/devrel/commit/fd3ba097b36aa6f311160f1af690b57cde934470))
* removed comments & added newlines in the proxy-endpoint-unifier wrapper ([b39a38f](https://github.com/apigee/devrel/commit/b39a38fed5bbb05f22c3e84771aca68cc0d6b938))
* updated CODEOWNERS ([655e5af](https://github.com/apigee/devrel/commit/655e5aff29d6a0273fefbf87b919b5dc3a9cce09))
* updated Licenses in the proxy-endpoint-unifier wrapper ([a7c8a03](https://github.com/apigee/devrel/commit/a7c8a030e40e55aede631d5df438265012ac7ddd))


### Bug Fixes

* added execute permissions on pipeline.sh ([cbae732](https://github.com/apigee/devrel/commit/cbae7326cf2475efddc21a018034cc85a40d0512))
* added support for FS read when proxy root xml is empty ([f821756](https://github.com/apigee/devrel/commit/f82175625f80d44fdeb78f25788d5846c56042a2))
* addressed PR comments ([d2db718](https://github.com/apigee/devrel/commit/d2db7181d950b742641b36ad9f2e55a63900cc92))
* changes to proxy endpoint unifier readme ([b245415](https://github.com/apigee/devrel/commit/b245415ceac9fce9b5247d6261497058faf9fe79))
* removing manifests , fixing Cache Policy & target endpoint ([5f92893](https://github.com/apigee/devrel/commit/5f92893d1fe0fdcc164feea9ff41d7595e6477d9))

## [1.12.0](https://github.com/apigee/devrel/compare/v1.11.0...v1.12.0) (2023-08-08)


### Features

* cloud build job to delete stale image artifacts ([2e1e923](https://github.com/apigee/devrel/commit/2e1e923e46d5e8405edd513253c9ac83804c4d55))
* fix semantic changes from httpbin to mocktarget ([87a376f](https://github.com/apigee/devrel/commit/87a376f93f041ec7d91c36ffc854250890d278cd))
* remove hackish fix since mocktarget now supports query param args ([e4c2280](https://github.com/apigee/devrel/commit/e4c2280f3dc736bba4a05f9ba6f97c4c2afadb3f))
* replace httpbin with mocktarget for identity facade and envoy quickstart ([b3fcfb9](https://github.com/apigee/devrel/commit/b3fcfb91a8afd126fca0588cd5c2e1375d243c24))
* replace httpbin.org with mocktarget.apigee.net ([58a8185](https://github.com/apigee/devrel/commit/58a81857cb4fdff4edaa6542aeb32707eefb3d48))

## [1.11.0](https://github.com/apigee/devrel/compare/v1.10.1...v1.11.0) (2023-07-05)


### Features

* bump hybrid quickstart to 1.10.0 ([7271b8f](https://github.com/apigee/devrel/commit/7271b8f6dd50ba1963463b9310e2840002a0c103))


### Bug Fixes

* bump jenkins version to 2.346.3 and update plugin version ([1f49f8c](https://github.com/apigee/devrel/commit/1f49f8c9ecfe8f80268b58aea9b63f7083332493))

## [1.10.1](https://github.com/apigee/devrel/compare/v1.10.0...v1.10.1) (2023-06-20)


### Bug Fixes

* **data-api:** remove nullable fields from data-api test cases ([7767d7b](https://github.com/apigee/devrel/commit/7767d7bb86ad5823fb6a5b037a0a06c376f6dca5))

## [1.10.0](https://github.com/apigee/devrel/compare/v1.9.1...v1.10.0) (2023-05-26)


### Features

* introducing eventarc apihub reference ([45e087d](https://github.com/apigee/devrel/commit/45e087d50e7088c339823cb47d6ecb7cdefdc60c), [a227b22](https://github.com/apigee/devrel/commit/a227b227364fd1641ba0549fc1b14a4c21d56041), [a4293be](https://github.com/apigee/devrel/commit/a4293be3c7fa9eb36dbfe1c68653c6cc61077418), [1705882](https://github.com/apigee/devrel/commit/17058829560253f727571c5979a05e990102ca26))

## [1.9.1](https://github.com/apigee/devrel/compare/v1.9.0...v1.9.1) (2023-05-23)


### Bug Fixes

* **hybrid-quickstat:** add org-scoped UDCA SA binding ([eba3ab6](https://github.com/apigee/devrel/commit/eba3ab6d95d393785d43ae832d8ca85ecaa49e7c))

## [1.9.0](https://github.com/apigee/devrel/compare/v1.8.0...v1.9.0) (2023-05-19)


### Features

* bump hybrid 1.9.2 plus local httpbin demo service ([da8b052](https://github.com/apigee/devrel/commit/da8b052b47b8809522daabefc720706477267491))


### Bug Fixes

* removing deprecated API, no longer needed for Apigee hybrid ([2cd7190](https://github.com/apigee/devrel/commit/2cd71903cf603d410f237c80b675fc440b7be44b))

## [1.8.0](https://github.com/apigee/devrel/compare/v1.7.0...v1.8.0) (2023-02-08)


### Features

* added unsupported apis in report ([0f7e994](https://github.com/apigee/devrel/commit/0f7e994dc4bda25a58390d635704a083e0df37ee))


### Bug Fixes

* remove heading named unsupported ([c7b960f](https://github.com/apigee/devrel/commit/c7b960f448b2c3006e43a131bbff1f4d4e002fd1))
* report data representation changed ([35cd4ca](https://github.com/apigee/devrel/commit/35cd4ca13d694a602bb142e335081684aa68050b))
* user details in report ([173c65c](https://github.com/apigee/devrel/commit/173c65c9bce404109b440cbe3d6348d1bcee7633))

## [1.7.0](https://github.com/apigee/devrel/compare/v1.6.1...v1.7.0) (2022-12-20)


### Features

* bump sackmesser docker image to latest versions ([351279d](https://github.com/apigee/devrel/commit/351279d9b8870bf00ebb351912d2dd6707c21d6e))


### Bug Fixes

* reference Apigee jars for Java callout example ([565d928](https://github.com/apigee/devrel/commit/565d9284e6e069b5b82a8ee715ddd26f06fd7738))

## [1.6.1](https://github.com/apigee/devrel/compare/v1.6.0...v1.6.1) (2022-12-09)


### Bug Fixes

* bump hybrid quickstart to latest 1.8.3 ([a2bd699](https://github.com/apigee/devrel/commit/a2bd699370dfa5f63e144900e01be2d92b4b455d))

## [1.6.0](https://github.com/apigee/devrel/compare/v1.5.0...v1.6.0) (2022-12-08)


### Features

* move sackmesser to Apigee API for CRUD on kvm entries in Apigee (breaking for hybrid &lt;1.8) ([93bb22e](https://github.com/apigee/devrel/commit/93bb22e73a8585c2260db6e102693811d5dca8a3))


### Bug Fixes

* force token refresh in pineline.sh ([978181e](https://github.com/apigee/devrel/commit/978181e9c77c3db364bb1b364fe13c077192bc61))
* more aggressive gcloud token refreshes ([63ad536](https://github.com/apigee/devrel/commit/63ad53601671568b029ba9ce60a126d0b649ab87))
* more aggressive token refresh for recaptcha example ([bdcdef2](https://github.com/apigee/devrel/commit/bdcdef241adff69573b8e97a73c435f1c9332832))

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
