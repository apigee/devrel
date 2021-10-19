# KVM Admin Proxy

Depending on the Apigee deployment model you might have Management APIs for
accessing and modifying the entries of Apigee Key Value Maps (KVMs). In Apigee
hybrid and Apigee X the access to entries of the KVMs is not provided via the
Apigee APIs and you will need to leverage Apigee policies to perform CRUD
operations on the KVM contents.

For more background information, please see [this](https://community.apigee.com/articles/89782/providing-kvm-content-apis-for-apigee-x-and-hybrid.html)
article in the Apigee community.

This project provides a reference implementation for how to read, write and
delete entries within environment scoped KVMs in Apigee X or hybrid.

**Note:** For simplicity his reference implementation leverages cloud based
Apigee API
[organizations.environments.testIamPermissions](https://cloud.google.com/apigee/docs/reference/apis/apigee/rest/v1/organizations.environments/testIamPermissions)
for authorization. The GET, POST, DELETE operations of this API correspond to
list, create and delete IAM permissions on keyvaluemaps. The proxy needs access
to `apigee.googleapis.com` to work correctly. Calling the Apigee Management APIs
is generally considered an anti-pattern and can lead to
[quota](https://console.cloud.google.com/iam-admin/quotas) exhaustion we
therefore suggest to review if this is a suitable tradeoff or swap the
existing authentication mechanism on the KVM admin proxy with a authentication
of your choice.

## (Prerequisite) Create a KVM

```sh
export TOKEN=$(gcloud auth print-access-token)
export APIGEE_ORG=my-org-name
export KVM_NAME=my-kvm
```

For an environment-scoped KVM run the following:

```sh
export APIGEE_ENV=my-env

curl -X POST \
    "https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/environments/$APIGEE_ENV/keyvaluemaps" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"name\":\"$KVM_NAME\",\"encrypted\": true}"
```

For an organization-scoped KVM run the following:

```sh
curl -X POST \
    "https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/keyvaluemaps" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"name\":\"$KVM_NAME\",\"encrypted\": true}"
```

## Create the Proxy

```sh
mvn clean install -ntp -B -Pgoogleapi -Dtoken="$TOKEN" \
  -Dorg="$APIGEE_ORG" -Dapigee.env="$APIGEE_ENV"
```

## Use the KVM Proxy

First, set the hostname that is used to reach your KVM admin proxy:

```sh
export API_HOSTNAME=api.my-domain.com
```

and the following configuration

```sh
export TOKEN=$(gcloud auth print-access-token)
export APIGEE_ORG=my-org-name
export KVM_NAME=my-kvm
export APIGEE_ENV=my-env # (env-scoped KVM only)
```

## Create or Update a KVM entry

Environment-scoped KVM with a JSON request payload:

```sh
curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{ "key": "foo", "value": "bar" }' \
    "https://$API_HOSTNAME/kvm-admin/v1/organizations/$APIGEE_ORG/environments/$APIGEE_ENV/keyvaluemaps/$KVM_NAME/entries"
```

Environment-scoped KVM with a form payload:

```sh
curl -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -d key=foo -d value=bar \
    "https://$API_HOSTNAME/kvm-admin/v1/organizations/$APIGEE_ORG/environments/$APIGEE_ENV/keyvaluemaps/$KVM_NAME/entries"
```

When used with the cURL utility, the form payload option allows you to obtain
the `value` for the key-value pair from a text file. For example, the value
could be a PEM-encoded private key, the contents of a JSON file, and so on. This
command populates the value of the "foo" key in an Environment-scoped KVM with
the contents of a text file:

```sh
curl -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -d key=foo --data-urlencode value@/path/to/file/here.txt \
    "https://$API_HOSTNAME/kvm-admin/v1/organizations/$APIGEE_ORG/environments/$APIGEE_ENV/keyvaluemaps/$KVM_NAME/entries"
```

Organization-scoped KVM with a JSON request payload:

```sh
curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{ "key": "foo", "value": "bar" }' \
    "https://$API_HOSTNAME/kvm-admin/v1/organizations/$APIGEE_ORG/keyvaluemaps/$KVM_NAME/entries"
```

Organization-scoped KVM with a form request payload:

```sh
curl -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -d key=foo -d value=bar \
    "https://$API_HOSTNAME/kvm-admin/v1/organizations/$APIGEE_ORG/keyvaluemaps/$KVM_NAME/entries"
```

Organization-scoped KVM with a value obtained from a file:

```sh
curl -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -d key=foo --data-urlencode value@/path/to/file/here.txt \
    "https://$API_HOSTNAME/kvm-admin/v1/organizations/$APIGEE_ORG/keyvaluemaps/$KVM_NAME/entries"
```

## Read a KVM entry

Environment-scoped KVM:

```sh
curl -X GET \
    -H "Authorization: Bearer $TOKEN" \
    "https://$API_HOSTNAME/kvm-admin/v1/organizations/$APIGEE_ORG/environments/$APIGEE_ENV/keyvaluemaps/$KVM_NAME/entries/foo"
```

Organization-scoped KVM:

```sh
curl -X GET \
    -H "Authorization: Bearer $TOKEN" \
    "https://$API_HOSTNAME/kvm-admin/v1/organizations/$APIGEE_ORG/keyvaluemaps/$KVM_NAME/entries/foo"
```

## Delete a KVM entry

Environment-scoped KVM:

```sh
curl -X DELETE \
    -H "Authorization: Bearer $TOKEN" \
    "https://$API_HOSTNAME/kvm-admin/v1/organizations/$APIGEE_ORG/environments/$APIGEE_ENV/keyvaluemaps/$KVM_NAME/entries/foo"
```

Organization-scoped KVM:

```sh
curl -X DELETE \
    -H "Authorization: Bearer $TOKEN" \
    "https://$API_HOSTNAME/kvm-admin/v1/organizations/$APIGEE_ORG/keyvaluemaps/$KVM_NAME/entries/foo"
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
