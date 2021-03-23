# KVM Admin Proxy

Depending on the Apigee deployment model you might have Management APIs for
accessing and modifying the entries of Apigee Key Value Maps (KVMs). In Apigee
hybrid and Apigee X the access to entries of the KVMs is not provided via the
Apigee APIs and you will need to leverage Apigee policies to perform CRUD
operations on the KVM contents.
For more background information, please see [this](https://community.apigee.com/articles/89782/providing-kvm-content-apis-for-apigee-x-and-hybrid.html)
article in the Apigee community.

This project provides a reference implementation for how to read, write and
delete entries within environment scoped KVMs inside Apigee regardless of the
deployment model and the existence of KVM management APIs.

**Note:** This reference implementation leverages cloud based Apigee API
[organizations.environments.testIamPermissions](https://cloud.google.com/apigee/docs/reference/apis/apigee/rest/v1/organizations.environments/testIamPermissions)
for authorization. The GET, POST, DELETE operations of this API correspond
to list, create and delete IAM permissions on keyvaluemaps. The proxy needs
access to apigee.googleapis.com to work correctly.

## (Prerequisite) Create a KVM

**Note:** Apigee SaaS currently does not allow for dynamic KVM names via the
MapName element. It will automatically default to a KVM called `kvmap` and
ignore the provided map name in the path.

```sh
export TOKEN=$(gcloud auth print-access-token)
export APIGEE_ORG=my-org-name
export APIGEE_ENV=my-env
export KVM_NAME=my-kvm

curl -X POST \
    "https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/environments/$APIGEE_ENV/keyvaluemaps" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"name\":\"$KVM_NAME\",\"encrypted\": true}"
```

## Create the Proxy

### Google APIs (Apigee hybrid and Apigee X)

```sh
mvn clean install -ntp -B -Pgoogleapi -Dtoken=$(gcloud auth print-access-token) \
  -Dorg=$APIGEE_ORG -Dapigee.env=$APIGEE_ENV
```

### Apigee APIs (Apigee Public Cloud)

```sh
mvn clean install -ntp -B -Papigeeapi -Dorg=$APIGEE_ORG -Denv=$APIGEE_ENV \
  -Dusername=$APIGEE_USER -Dpassword=$APIGEE_PASS
```

## Use the KVM Proxy

First, set the hostname for your API (i.e. the `virtualhost` for your Apigee
public cloud or your hostname for your env group in Apigee hybrid.)

```sh
export $API_HOSTNAME=$APIGEE_ORG-$APIGEE_ENV.apigee.net
# or
export $API_HOSTNAME=api.my-domain.com
```

## Create or Update a KVM entry

```sh
export TOKEN=$(gcloud auth print-access-token)
export APIGEE_ORG=my-org-name
export APIGEE_ENV=my-env
export KVM_NAME=my-kvm

curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{ "key": "foo", "value": "bar" }' \
    "https://$API_HOSTNAME/kvm-admin/v1/organizations/$APIGEE_ORG/environments/$APIGEE_ENV/keyvaluemaps/$KVM_NAME/entries"
```

## Read a KVM entry

```sh
curl -X GET \
    -H "Authorization: Bearer $TOKEN" \
    "https://$API_HOSTNAME/kvm-admin/v1/organizations/$APIGEE_ORG/environments/$APIGEE_ENV/keyvaluemaps/$KVM_NAME/entries/foo"
```

## Delete a KVM entry

```sh
curl -X DELETE \
    -H "Authorization: Bearer $TOKEN" \
    "https://$API_HOSTNAME/kvm-admin/v1/organizations/$APIGEE_ORG/environments/$APIGEE_ENV/keyvaluemaps/$KVM_NAME/entries/foo"
```

## Troubleshooting

If you see persistent 500 errors, ensure the deployed proxy has access to the
domain apigee.googleapis.com.

The keyvaluemap you intend to work on needs to be created in advance either
through the UI or through the corresponding management API mentioned above.
When the keyvaluemap does not exist you will see a 404 error.

Removing all entries in a keyvaluemap does not remove the keyvaluemap. You will
have to use the UI or the corresponding management API to delete the
keyvaluemap.

A 403 or 401 error is returned when the token provided does not have the
permission to perform the corresponding operation on the keyvaluemap. Contact
your Google Cloud admin to check if the GCP user has permissions to update the
keyvaluemap.

Role and permission changes to the user account in IAM usually reflect
instantaneously.

KVM is backed by an eventually consistent store and hence a KVM entry may
appear to be still around for a brief moment after being deleted. This is
expected.
