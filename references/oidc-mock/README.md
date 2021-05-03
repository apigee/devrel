# OIDC Mock

A simple OIDC mock identity provider implementation.
Standard endpoints are exposed, like:

- Authorize
- Token
- Introspection
- UserInfo
- Certs
- Discovery document

## Dependencies

- [Maven](https://maven.apache.org/)
- [NodeJS](https://nodejs.org/en/) LTS version or above
- Apigee Evaluation [Organization](https://login.apigee.com/sign__up)

## Quick start

    export APIGEE_ORG=xxx
    export APIGEE_ENV=xxx
    export APIGEE_USER=xxx
    export APIGEE_PASS=xxx

    export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"
    sackmesser deploy --apigeeapi -o "$APIGEE_ORG" -e "$APIGEE_ENV" -u "$APIGEE_USER" -p "$APIGEE_PASS"
    npm i
    npm test

## OIDC Mock documentation

The OIDC mock Identity Provider (IdP) is a mock version of an OIDC
compliant IdP.

It is proposed as an Apigee API Proxy and can be deployed on Apigee
Edge public Cloud, Apigee hybrid and Apigee Edge private Cloud.

In the following sections, we describe the different characteristics
of the OIDC Mock IdP:

- Client App
- Access Token
- ID Token
- Endpoints:
    1. Discovery document
    2. Authorize
    3. Token
    4. Introspection
    5. Userinfo
    6. JWKS (certs)

### Client App

The name of the client app is set to **dummy-client_app**
The value of the callback url is not checked by the mock OIDC IdP,
so you can choose the value, which is the most convenient for you
like: [https://httpbin.org/get](https://httpbin.org/get)

**There is one exception**: should you need working with an invalid
```redirect_uri``` value, you can use the only value considered
invalid by the OIDC Mock :
`https://example.com/invalid`

#### Client App Credentials

Valid client app credentials are in the following form:

- Client Id (aka. consumer key or app key) : MUST start with **dummy-client_id**

    Valid examples are:
  - **dummy-client_id**
  - **dummy-client_id**-123abc
  - **dummy-client_id**-xxx

- Client Secret (aka. consumer secret or app secret): MUST start with **dummy-client_secret**

    Valid examples are:

  - **dummy-client_secret**
  - **dummy-client_secret**-456def
  - **dummy-client_secret**-yyy

### Access Tokens

Access tokens delivered are in the following form:

- **dummy-access_token**-timestamp

Here is an example: **dummy-access_token-1606917416617**

Valid access tokens must start with the pattern: “dummy-access_token”

### ID Token

The OIDC Mock IdP delivers a default id token.

Here is its value:

    eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.POstGetfAytaZS82wHcjoTyoqhMyxXiWdR7Nn7A29DNSl0EiXLdwJ6xC6AfgZWF1bOsS_TuYI3OG85AmiExREkrS6tDfTQ2B3WXlrr-wp5AokiRbz3_oB4OxG-W9KcEEbDRcZc0nH3L7LzYptiy1PtAylQGxHTWZXtGz4ht0bAecBgmpdgXMguEIcoqPJ1n3pIWk_dUZegpqx0Lka21H6XxUTxiy8OcaarA8zdnPUnV6AmNP3ecFawIFYdvJB_cm-GvpCSbr8G8y_Mllj8f4x9nBH8pQux89_6gUY618iYv7tuPWBFfEbLxtF2pZS6YC1aSfLQxeNe8djT9YjpvRZA

This id token is the one proposed on jwt.io, as shown here:

If needed, you can modify this value.
For this, please modify the content of the
[AM-SetIdToken.xml](./apiproxy/policies/AM-SetIdToken.xml),
as shown on the following picture:

![AM-SetIdToken.xml](./img/01.png "Modifying the value of th ID token")

### Endpoints

Available endpoints are the following ones:

1. Discovery document
2. Authorize
3. Token
4. Introspection
5. Userinfo
6. JWKS (certs)

Once the OIDC mock API Proxy has been installed on a target organization
 and deployed into an environment, here are values for these different
 endpoints and method available for each of them:

| Endpoint | Available method + URI |
|:----|:---|
|Discovery document|GET /v1/openid-connect/.well-known/openid-configuration|
| Authorize             | GET /v1/openid-connect/authorize |
| Token                 | POST /v1/openid-connect/token |
| Introspection         | POST /v1/openid-connect/introspect |
| UserInfo              | GET /v1/openid-connect/userinfo |
| JWKS/Certs            | GET /v1/openid-connect/certs |

#### Endpoint details

Here is a detailed description of each endpoints and in particular the
list of required parameters for each of them:

##### Authorize

| HTTP Method |
|:----|
| GET |

| Base Path |
|:----|
| /v1/openid-connect |

| Endpoint URI |
|:----|
| /authorize |

If you need to change the value of the endpoint URI, please make the
modification on the following file:
[default.xml](./apiproxy/proxies/default.xml),
as shown on the folowing picture:

![default.xml](./img/02.png "Modifying the authorization endpoint")

List of parameters:

| Name| Type (query/header/form) | Value | Required (yes/no) |
|:----|:-----:|:----:|:----:|
| client_id | query | cf. Client App Credentials | yes |
| state | query | | yes |
| scope | query | | yes |
| response_type | query | code | yes |
| redirect_uri | query | | yes |
| nonce | query | | no |
| prompt | query | consent | no |

Example:

    Method:
    GET
    URI:
    /v1/openid-connect/authorize?client_id=dummy-client_id-xxx&state=12345&scope=openid%20email&response_type=code&redirect_uri=https://httpbin.org/get

Output:

Authentication page of the mock OIDC identity provider:

![Authentication Page](./img/03.png "Authentication page of the OIDC Mock IdP")

As there is no user authentication,
you can enter login and password of your choice.
As an example, here is an extract of the HTML body of the authentication page:

![Authentication HTML Content](./img/04.png "HTML content of the Authentication page")

Consent page of the mock OIDC identity provider:

![Consent Page](./img/05.png "Consent page of the OIDC Mock IdP")

“**Allow**” and “**Reject**” trigger the same result,
which is an HTTP redirection (302) to the **redirect_uri**

As an example, here is an extract of the HTML body of the consent page:

![Consent Page HTML Content](./img/06.png "HTML content of the Authentication page")

##### Token

| HTTP Method |
| :----|
| POST  |

| Base Path |
| :----|
| /v1/openid-connect |

| Endpoint URI |
| :----|
|/token|

List of parameters:

| Name| Type (query/header/form) | Value | Required (yes/no) |
|:----|:-----:|:----:|:----:|
| code | form | | yes |
| scope | form | | yes |
| grant_type | form | authorization_code | yes |
| state | form | | yes |
| redirect_uri | form | | yes |
|authorization|header|Basic auth header value of clientId and clientSecret|yes|
| Content-Type | header | application/x-www-form-urlencoded | yes |
| Accept | header | application/json | no |

Example:

    Method:
    POST
    Headers:
    Authorization: Basic ZHVtbXktY2xpZW50X2lkOmR1bW15LWNsaWVudF9zZWNyZXQteHh4
    Content-Type: application/x-www-form-urlencoded
    URI:
    /v1/openid-connect/token
    Body:
    scope: openid email
    code: dummy-authcode-1606499443624
    state: 12345
    redirect_uri: https://httpbin.org/get
    grant_type: authorization_code

Output:

A JSON content with a valid access token and id token:

    {
        "access_token": "dummy-access_token-1606917416617",
        "expires_in": 3600,
        "token_type": "bearer",
        "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.POstGetfAytaZS82wHcjoTyoqhMyxXiWdR7Nn7A29DNSl0EiXLdwJ6xC6AfgZWF1bOsS_TuYI3OG85AmiExREkrS6tDfTQ2B3WXlrr-wp5AokiRbz3_oB4OxG-W9KcEEbDRcZc0nH3L7LzYptiy1PtAylQGxHTWZXtGz4ht0bAecBgmpdgXMguEIcoqPJ1n3pIWk_dUZegpqx0Lka21H6XxUTxiy8OcaarA8zdnPUnV6AmNP3ecFawIFYdvJB_cm-GvpCSbr8G8y_Mllj8f4x9nBH8pQux89_6gUY618iYv7tuPWBFfEbLxtF2pZS6YC1aSfLQxeNe8djT9YjpvRZA"
    }

*Introspection*
HTTP Method

| HTTP Method |
| :----|
| POST  |

| Base Path |
| :----|
| /v1/openid-connect |

| Endpoint URI |
| :----|
| /introspect |

List of parameters:

| Name | Type (query/header/form) | Value | Required (yes/no) |
|:----|:-----:|:----:|:----:|
| token | form |  a valide token cf. Access Tokens | yes |
|authorization|header|Basic auth header value of clientId and clientSecret|yes|
| Content-Type | header | application/x-www-form-urlencoded | yes |
| Accept | header | application/json | no |

Example:

    Method:
    POST
    Headers:
    Authorization: Basic ZHVtbXktY2xpZW50X2lkOmR1bW15LWNsaWVudF9zZWNyZXQteHh4
    Content-Type: application/x-www-form-urlencoded
    URI:
    /v1/openid-connect/introspect
    Body:
    token:dummy-access_token-1606500122994

Output:

A JSON content with validation response:

    {
        "active": true,
        "client_id": "dummy-client_id-123abc",
        "username": "jdoe",
        "scope": "openid email",
        "iat": 1516239022,
        "iss": ""issuer": "https: //<IdP_hostname>/v1/openid-connect"
    }

##### UserInfo

| HTTP Method |
| :----|
| GET  |

| Base Path |
| :----|
| /v1/openid-connect|

| Endpoint URI |
| :----|
| /userinfo |

List of parameters:

| Name | Type (query/header/form) | Value | Required (yes/no) |
|:----|:-----:|:----:|:----:|
| authorization | header | Bearer Token - cf. Access Tokens | yes |

Example:

    Method:
    GET
    Headers:
    Authorization: Bearer dummy-access_token-xxxx
    URI:
    /v1/openid-connect/userinfo

Output:

A JSON content with user information:

    {
        "sub": "248289761001",
        "name": "Jane Doe",
        "given_name": "Jane",
        "family_name": "Doe",
        "email": "janedoe@example.com",
        "picture": "http://example.com/janedoe/me.jpg"
    }

##### JWKS

| HTTP Method |
| :----|
| GET  |

| Base Path |
| :----|
| /v1/openid-connect |

| Endpoint URI |
| :----|
| /certs |

List of parameters:

None

Example:

    Method:
    GET
    URI:
    /v1/openid-connect/certs

Output:

A JWKS content (JSON):

    {
        "keys": [
            {
                "kid": "oidcmock",
                "kty": "RSA",
                "use": "sig",
                "n": "nzyis1ZjfNB0bBgKFMSvvkTtwlvBsaJq7S5wA-kzeVOVpVWwkWdVha4s38XM_pa_yr47av7-z3VTmvDRyAHcaT92whREFpLv9cj5lTeJSibyr_Mrm_YtjCZVWgaOYIhwrXwKLqPr_11inWsAkfIytvHWTxZYEcXLgAXFuUuaS3uF9gEiNQwzGTU1v0FqkqTBr4B8nW3HCN47XUu0t8Y0e-lf4s4OxQawWD79J9_5d3Ry0vbV3Am1FtGJiJvOwRsIfVChDpYStTcHTCMqtvWbV6L11BWkpzGXSW4Hv43qa-GSYOD2QU68Mb59oSk2OB-BtOLpJofmbGEGgvmwyCI9Mw",
                "e": "AQAB",
                "alg": "RS256"
            }
        ]
    }

The JWKS can be used to validate theJWT token that has been returned when
executing the ```POST /token``` endpoint. If you modified the value of the
ID Token returned by the OIDC Mock IdP please make sure to also modify the
JWKS content using a tool of your choice.
You need to modify the [AM-SetJWKS.xml](./apiproxy/policies/AM-SetJWKS.xml),
as shown on the following picture:

![AM-SetJWKS.xml](./img/07.png "Modifying the JWKS keys")

##### Discovery Document

| HTTP Method |
| :----|
| GET |

| Base Path |
| :----|
| /v1/openid-connect |

| Endpoint URI |
| :----|
| /.well-known/openid-configuration |

List of parameters:

None

Example:

    Method:
    GET
    URI:
    /v1/openid-connect/.well-known/openid-configuration

Output:

A JSON content providing the different endpoints,
the issuer and other security configuration specific to the Mock OIDC IdP:

    {
        "issuer": "https://jeanmartindemodevrel-eval-test.apigee.net/v1/openid-connect",
        "authorization_endpoint": "https://jeanmartindemodevrel-eval-test.apigee.net/v1/openid-connect/authorize",
        "token_endpoint": "https://jeanmartindemodevrel-eval-test.apigee.net/v1/openid-connect/token",
        "introspection_endpoint": "https://jeanmartindemodevrel-eval-test.apigee.net/v1/openid-connect/token/introspect",
        "userinfo_endpoint": "https://jeanmartindemodevrel-eval-test.apigee.net/v1/openid-connect/userinfo",
        "end_session_endpoint": "https://jeanmartindemodevrel-eval-test.apigee.net/v1/openid-connect/logout",
        "jwks_uri": "https://jeanmartindemodevrel-eval-test.apigee.net/v1/openid-connect/certs",
        "check_session_iframe": "https://jeanmartindemodevrel-eval-test.apigee.net/v1/openid-connect/login-status-iframe.html",
        "grant_types_supported": [
            "authorization_code",
            "implicit",
            "refresh_token",
            "password",
            "client_credentials"
        ],
        "response_types_supported": [
            "code",
            "none",
            "id_token",
            "token",
            "id_token token",
            "code id_token",
            "code token",
            "code id_token token"
        ],
        "subject_types_supported": [
            "public",
            "pairwise"
        ],
        "id_token_signing_alg_values_supported": [
            "PS384",
            "ES384",
            "RS384",
            "HS256",
            "HS512",
            "ES256",
            "RS256",
            "HS384",
            "ES512",
            "PS256",
            "PS512",
            "RS512"
        ],
        "id_token_encryption_alg_values_supported": [
            "RSA-OAEP",
            "RSA1_5"
        ],
        "id_token_encryption_enc_values_supported": [
            "A256GCM",
            "A192GCM",
            "A128GCM",
            "A128CBC-HS256",
            "A192CBC-HS384",
            "A256CBC-HS512"
        ],
        "userinfo_signing_alg_values_supported": [
            "PS384",
            "ES384",
            "RS384",
            "HS256",
            "HS512",
            "ES256",
            "RS256",
            "HS384",
            "ES512",
            "PS256",
            "PS512",
            "RS512",
            "none"
        ],
        "request_object_signing_alg_values_supported": [
            "PS384",
            "ES384",
            "RS384",
            "HS256",
            "HS512",
            "ES256",
            "RS256",
            "HS384",
            "ES512",
            "PS256",
            "PS512",
            "RS512",
            "none"
        ],
        "response_modes_supported": [
            "query",
            "fragment",
            "form_post"
        ],
        "registration_endpoint": "https://jeanmartindemodevrel-eval-test.apigee.net/v1/openid-connect//clients-registrations",
        "token_endpoint_auth_methods_supported": [
            "private_key_jwt",
            "client_secret_basic",
            "client_secret_post",
            "tls_client_auth",
            "client_secret_jwt"
        ],
        "token_endpoint_auth_signing_alg_values_supported": [
            "PS384",
            "ES384",
            "RS384",
            "HS256",
            "HS512",
            "ES256",
            "RS256",
            "HS384",
            "ES512",
            "PS256",
            "PS512",
            "RS512"
        ],
        "claims_supported": [
            "aud",
            "sub",
            "iss",
            "auth_time",
            "name",
            "given_name",
            "family_name",
            "preferred_username",
            "email",
            "acr"
        ],
        "claim_types_supported": [
            "normal"
        ],
        "claims_parameter_supported": false,
        "scopes_supported": [
            "openid",
            "address",
            "email",
            "microprofile-jwt",
            "offline_access",
            "phone",
            "profile",
            "roles",
            "web-origins"
        ],
        "request_parameter_supported": true,
        "request_uri_parameter_supported": true,
        "code_challenge_methods_supported": [
            "plain",
            "S256"
        ],
        "tls_client_certificate_bound_access_tokens": true
    }

Have fun using the OIDC Mock IdP !
