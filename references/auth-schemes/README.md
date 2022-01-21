# API Auth Schemes

## Description
An Apigee reference implementation to demonstrate a variety of frequently-used authentication and authorization schemes.
Integration tests are included to invoke each endpoint and scheme that is made available by the API Proxy. The list of
schemes mentioned and demonstrated here is not a complete or comprehensive list of schemes supported by Apigee.

## Schemes
- API Key Verification _(for identification, not authentication)_
- Basic Authentication (RFC 7617)
- JWT Verification (RFC 7519)
- OAuth Bearer Token Verification (RFC 6749)

## Dependencies
- [`apigee-sackmesser`](https://github.com/apigee/devrel/tree/main/tools/apigee-sackmesser)
- `npm` and Node.js


## Quick Start
To deploy the artifacts, first appropriately set the following environment variables per [PIPELINES.md](../../PIPELINES.md):
```sh
export APIGEE_X_ORG=
export APIGEE_X_ENV=
export APIGEE_X_HOSTNAME=
export APIGEE_X_TOKEN=$(gcloud auth print-access-token)
```

Then, execute `pipeline.sh`:
```
sh ./pipeline.sh
```
Note that the pipeline will automatically execute integration tests after a successful deployment. To clean up all
artifacts, set the following variable and re-run pipeline.sh:
```
APIGEE_AUTH_SCHEMES_CLEAN_UP=true; sh pipeline.sh
```

## Tests
To run the integration tests, first retrieve Node.js dependencies with:
```
npm install
```
and then:
```
npm run test
```

## Example Requests
For additional examples, including negative test cases,
see the [auth-schemes.feature](./test/integration/features/auth-schemes.feature) file.

### Verify API Key
Copy the AuthApp's Client ID from Apigee and include it in the following request:
```
curl -v https://$APIGEE_X_HOSTNAME/auth-schemes/v0/api-key -H "API-Key: $CLIENT_ID"
```
> _Note: API key verification should not be considered a strong method of authentication for APIs._


### Basic Authentication (RFC 7617)
```
curl -v https://$APIGEE_X_HOSTNAME/auth-schemes/v0/basic-auth -u alex:universe
```
> _Note: Under normal circumstances, avoid providing passwords on the command itself using `-u`. The credentials used and expected here are for demonstration purposes only._


### JWT Verification (RFC 7519)
First obtain a short-lived signed JWT using the helper endpoint:
```
curl -v -XPOST https://$APIGEE_X_HOSTNAME/auth-schemes/v0/helpers/jwt
```
Copy the value of the `Generated-JWT` response header from the previous request and include it in the following request:
```
curl -v https://$APIGEE_X_HOSTNAME/auth-schemes/v0/jwt -H "JWT: $JWT"
```

### OAuth Bearer Token (RFC 6749)
First obtain a short-lived opaque access token using the helper endpoint:
```
curl -v -XPOST https://$APIGEE_X_HOSTNAME/auth-schemes/v0/helpers/oauth -u $CLIENT_ID:$CLIENT_SECRET -d "grant_type=client_credentials"
```
> _Note: Under normal circumstances, avoid providing secrets on the command itself using `-u`_

Copy the value of the `Generated-JWT` response header from the previous request and include it in the following request:
```
curl -v https://$APIGEE_X_HOSTNAME/auth-schemes/v0/oauth-token -H "Authorization: Bearer $TOKEN"
```

## Other Popular Schemes
### LDAP

The [external-callout-samples](https://github.com/srinandan/external-callout-samples/) repository contains an example
implementation for an [apigee-ldap-callout](https://github.com/srinandan/external-callout-samples/tree/main/apigee-ldap-callout)
which utilises Apigee's [ExternalCallout policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/external-callout-policy). This strategy can be used to verify credentials provided by a client with an LDAP directory service.

### Mutual TLS (mTLS)
Also known as client certificate authentication or mutual authentication, mTLS can be utilised to achieve transport
layer authentication of clients. For implementation details relating to Apigee X, see this [two](https://www.googlecloudcommunity.com/gc/Cloud-Product-Articles/Network-and-Envoy-Proxy-Configuration-to-manage-mTLS-on-Apigee-X/ta-p/175146)-[part](https://www.googlecloudcommunity.com/gc/Cloud-Product-Articles/Network-and-Envoy-Proxy-Configuration-to-manage-mTLS-on-Apigee-X/ta-p/175152)
community article which comprehensively explains the necessary configuration. For implementation details relating to Apigee hybrid,
refer to the [official product documentation](https://cloud.google.com/apigee/docs/hybrid/latest/ingress-tls). In both cases,
the API Proxy will have access to the client certificate and a set of certificate attributes available as runtime variables.