# GCP Service Account Credentials

This shared flow can be used obtain access tokens for Google Cloud service accounts. Access tokens are cached in the default environment cache resource for 10min.

## Usage instructions

1. Create a service account in Google Cloud and assign it the necessary roles. See GCP [docs](https://cloud.google.com/iam/docs/creating-managing-service-accounts).
2. Create and download a json key for the service account. See GCP [docs](https://cloud.google.com/iam/docs/creating-managing-service-account-keys).
3. In your Apigee flow, make sure you have the `private.gcp.service_account.key` variable set. It should hold the full json key for the service account. You can do this by e.g. storing it as a value in an encrypted KVM.
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<KeyValueMapOperations async="false" continueOnError="false" enabled="true" name="KV.Lookup-SA-Key" mapIdentifier="MAP_NAME_HERE">
    <ExclusiveCache>false</ExclusiveCache>
    <ExpiryTimeInSecs>300</ExpiryTimeInSecs>
    <Get assignTo="private.gcp.service_account.key">
        <Key>
            <Parameter>MAP_ENTRY_KEY_HERE</Parameter>
        </Key>
    </Get>
    <Scope>environment</Scope>
</KeyValueMapOperations>
```
4. Either setting `gcp.scopes` or `gcp.target_audience`. Depending on whether you need a GCP JWT or opague access token.
  * `gcp.scopes` holds the required OAuth scopes as per the Google [docs](https://developers.google.com/identity/protocols/oauth2/scopes) and leads to an opague access token. This can be used e.g. to access Google services like the Google Translate API.
  * `gcp.target_audience` holds the target audience claim which should be set as the audience claim on the Google issued JWT. This can be used e.g. to authenticate Apigee against Cloud Run backends.

```xml
<AssignMessage async="false" name="AM.GCPScopes">
    <AssignVariable>
        <Name>gcp.scopes</Name>
        <Value>https://www.googleapis.com/auth/cloud-platform</Value>
    </AssignVariable>
    <IgnoreUnresolvedVariables>false</IgnoreUnresolvedVariables>
</AssignMessage>
```
5. After running this shared flow the access token is populated in the `private.gcp.access_token` flow variable. Use this variable as the bearer token in calls against Google APIs.
