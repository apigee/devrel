# GCP Service Account Authentication - Shared Flow

This shared flow can be used obtain access tokens for Google Cloud service
accounts. Access tokens are cached in a dedicated environment cache resource
for 10min.

## Usage instructions

1. Create an environment cache resource called `gcp-tokens`
1. Create a service account in Google Cloud and assign it the necessary roles.
   See GCP
   [docs](https://cloud.google.com/iam/docs/creating-managing-service-accounts).
1. Create and download a json key for the service account. See GCP
   [docs](https://cloud.google.com/iam/docs/creating-managing-service-account-keys).
1. In your Apigee flow, make sure you have the `private.gcp.service_account.key`
   variable set. It should hold the full json key for the service account. The
   recommended approach is to store this value in an encrypted KVM and populate
   a private variable using KeyValueMapOperations policy at runtime.

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<KeyValueMapOperations name="KV.Lookup-SA-Key" mapIdentifier="MAP_NAME_HERE">
    <ExpiryTimeInSecs>300</ExpiryTimeInSecs>
    <Get assignTo="private.gcp.service_account.key">
        <Key>
            <Parameter>MAP_ENTRY_KEY_HERE</Parameter>
        </Key>
    </Get>
</KeyValueMapOperations>
```

1. Set one of the following variables `gcp.scopes` or `gcp.target_audience`
   depending on whether you need a GCP JWT or opaque access token.

* `gcp.scopes` is used to retrieve an opaque OAuth token and holds the required
  scopes per the Google
  [docs](https://developers.google.com/identity/protocols/oauth2/scopes). This
  access token can be used e.g. to access Google services like the Google
  Translate API.
* `gcp.target_audience` is used when retrieving a JWT token from Google. It
  holds the target audience claim which will be set as the audience claim on the
  issued JWT. This can be used e.g. to authenticate Apigee against Cloud Run
  backends.

```xml
<AssignMessage name="AM.GCPScopes">
    <AssignVariable>
        <Name>gcp.scopes</Name>
        <Value>https://www.googleapis.com/auth/cloud-platform</Value>
    </AssignVariable>
</AssignMessage>
```

1. After running this shared flow, the `private.gcp.access_token` flow variable
   will be set with the value of the access token. You can now present this
   token in the Authorization header in your subsequent requests to other Google
   APIs.
