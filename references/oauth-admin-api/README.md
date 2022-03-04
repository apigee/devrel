# OAuth Admin API

This reference implementation makes the OAuth2 token [revocation functionality](https://apidocs.apigee.com/docs/oauth-20-access-tokens/1/routes/organizations/%7Borg_name%7D/oauth2/revoke/post)
that existed in the Management API in Apigee Edge, available for  Apigee X and
hybrid.

## Prerequisites

The following commands assume you have set the following environment variables:

```sh
export APIGEE_X_ORG=
export APIGEE_X_ENV=
export APIGEE_X_HOSTNAME=
export APIGEE_X_TOKEN=$(gcloud auth print-access-token)
```

Because revoking tokens for existing API Proxies is a potentially disruptive
operation, you are strongly advised to protect this API proxy and issue
dedicated credentials for it. This implementation uses OAuth2 and assumes
that the proxy is included within a privileged API product which is only
available to Applications that should be treated similar to the access
credentials that control access to the corresponding Management APIs in
Apigee Edge.


You can do this using your regular automation process or follow the script
below for a demo:

```sh
# Create a Developer Resource
curl -X POST "https://apigee.googleapis.com/v1/organizations/$APIGEE_X_ORG/developers" \
-H "Authorization: Bearer $APIGEE_X_TOKEN" \
-H "Content-Type: application/json" \
-d '{ "email": "oauth-admin@example.com", "firstName": "oauth", "lastName": "admin", "userName": "oauthadmin" }'

# Create an API Product for administrating OAuth tokens
curl -X POST "https://apigee.googleapis.com/v1/organizations/$APIGEE_X_ORG/apiproducts" \
-H "Authorization: Bearer $APIGEE_X_TOKEN" \
-H "Content-Type: application/json" \
--data @<(cat <<EOF
{
  "name": "oauth-admin",
  "operationGroup": {
    "operationConfigs": [
      {
        "apiSource": "oauth-admin-v1",
        "operations": [
          {
            "resource": "/"
          }
        ],
        "quota": {}
      }
    ],
    "operationConfigType": "proxy"
  },
  "environments": [
    "$APIGEE_X_ENV"
  ],
  "attributes": [
    {
      "name": "access",
      "value": "private"
    }
  ],
  "displayName": "[INTERNAL] OAuth Administration Product",
  "approvalType": "manual"
}
EOF
)

# Create an App for the OAuth Admin
curl -X POST "https://apigee.googleapis.com/v1/organizations/$APIGEE_X_ORG/developers/oauth-admin@example.com/apps" \
-H "Authorization: Bearer $APIGEE_X_TOKEN" \
-H "Content-Type: application/json" \
--data @<(cat <<EOF
{
  "name": "oauth-admin-app",
  "apiProducts": [
    "oauth-admin"
  ]
}
EOF
)

APP_RESPONSE=$(curl "https://apigee.googleapis.com/v1/organizations/$APIGEE_X_ORG/developers/oauth-admin@example.com/apps/oauth-admin-app" \
-H "Authorization: Bearer $APIGEE_X_TOKEN")

CLIENT_ID=$(echo "$APP_RESPONSE" | jq -r '.credentials[0].consumerKey')
CLIENT_SECRET=$(echo "$APP_RESPONSE" | jq -r '.credentials[0].consumerSecret')

# Approve the App
curl -X POST "https://apigee.googleapis.com/v1/organizations/$APIGEE_X_ORG/developers/oauth-admin@example.com/apps/oauth-admin-app/keys/$CLIENT_ID/apiproducts/oauth-admin?action=approve" \
-H "Authorization: Bearer $APIGEE_X_TOKEN"
```

## Usage Guide

Set the `CLIENT_ID` and `CLIENT_SECRET` variables if you haven't set them using
the script above.

```sh
CLIENT_ID=''
CLIENT_SECRET=''
```

### Scenario A: Invalidate a token based on App ID

```sh
TOKEN_RESPONSE=$(curl -H "Content-Type: application/x-www-form-urlencoded" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -X POST "https://$APIGEE_X_HOSTNAME/oauth-admin/v1/oauth2/token" \
  -d "grant_type=client_credentials")

OAUTH_ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
APP_ID=$(echo "$TOKEN_RESPONSE" | jq -r '.application_name')
```

Invalidate all tokens for an app (including the admin token itself)

```sh
curl -H "Authorization: Bearer $OAUTH_ADMIN_TOKEN" \
  -X POST "https://$APIGEE_X_HOSTNAME/oauth-admin/v1/oauth2/revoke?app=$APP_ID" -v
```

Try again with the same token. This time the request will fail as all tokens
for the app have been invalidated.

```sh
curl -H "Authorization: Bearer $OAUTH_ADMIN_TOKEN" \
  -X POST "https://$APIGEE_X_HOSTNAME/oauth-admin/v1/oauth2/revoke?app=$APP_ID" -v
```


### Scenario B: Invalidate a token based on Enduser ID

Request a token and give it the end user ID of `bob`.

```sh
OAUTH_ADMIN_TOKEN=$(curl -H "Content-Type: application/x-www-form-urlencoded" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -X POST "https://$APIGEE_X_HOSTNAME/oauth-admin/v1/oauth2/token?app_enduser=bob" \
  -d "grant_type=client_credentials" | jq -r '.access_token')
```

Invalidate all tokens for an end user (including the admin token itself)

```sh
curl -H "Authorization: Bearer $OAUTH_ADMIN_TOKEN" \
  -X POST "https://$APIGEE_X_HOSTNAME/oauth-admin/v1/oauth2/revoke?enduser=bob"
```

Try again with the same token. This time the request will fail as all tokens
for `bob` have been invalidated.

```sh
curl -H "Authorization: Bearer $OAUTH_ADMIN_TOKEN" \
  -X POST "https://$APIGEE_X_HOSTNAME/oauth-admin/v1/oauth2/revoke?enduser=bob"
```
