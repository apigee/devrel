id: idp-okta-integration

# Apigee IDP integraiton with Okta

## Introduction

Welcome to the lab on  **Apigee Integration with Okta**!


The goal of this lab is to walk you through configuring and using the [Apigee Identity Facade](https://github.com/Teodelas/devrel/tree/main/references/identity-facade) to integrate with [Okta](www.okta.com) and authenticate users.


We assume the basic knowledge of Apigee platform and you will get the most from
this hackathon if you do.

Ideally you will have completed the Coursera Apigee
[Design](https://www.coursera.org/learn/api-design-apigee-gcp),
[Development](https://www.coursera.org/learn/api-development-apigee-gcp) and
[Security](https://www.coursera.org/learn/api-security-apigee-gcp) Courses.

Alternatively, completing the Apigee [API Jam](https://github.com/apigee/apijam)
will cover the same topics in less depth.

Lets get started!


## Flow

- Application developers use the Apigee Developer Portal to register and retrieve API keys
- Application developers use Okta Developer Portal to create A
- Client applications accessing public API hosted on Apigee will use HTTPS and
  API keys, and OAuth 2.0 access tokens from Okta
- Apigee communicates with target applications over TLS

## Prerequisites
- [Signup](https://developer.okta.com/signup/) for an Okta developer account
- Create an [Apigee Eval](https://cloud.google.com/apigee/docs/api-platform/get-started/eval-orgs) organization

### Tools

Here are the tools needed to complete the tasks:

- Web Browser (recent version of [Chrome](https://www.google.com/chrome/) or
  [Firefox](https://www.mozilla.org/en-GB/firefox/new/))
- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git),
- A REST Client - [Postman](https://www.postman.com/) or
  [Curl](https://curl.haxx.se/)


## Okta setup

1. Sign into your Okta developer portal
2. In the left hand side Navigate to Directoy - People
3. Click on **Add person**
4. 


