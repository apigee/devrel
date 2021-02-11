# KVM Admin Proxy

Depending on the Apigee deployment model you might have Management APIs for
accessing and modifying the content of Apigee Key Value Maps (KVMs). In Apigee
hybrid and Apigee X the access to the KVMs is not provided via the Apigee
APIs and you will need to leverage Apigee policies to perform CRUD operations
on the KVM contents. For more background information, please see [this](https://community.apigee.com/articles/89782/providing-kvm-content-apis-for-apigee-x-and-hybrid.html)
article in the Apigee community.

This project provides a reference implementation for how to read, write and
delete entries within environment scoped KVMs inside Apigee regardless of the
deployment model and the existence of KVM management APIs.

**Note:** This reference implementation does not include authentication or
authorization controls. Before exposing this API proxy, think about how you
would secure it from anonymous clients. Use of this proxy as-is, without
such controls, could lead to unauthorized manipulation of KVMs within your org.

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
curl -X POST -H "Content-Type: application/json" -d '{ "name": "foo", "value": "bar" }' "https://$API_HOSTNAME/kvm-admin/v1/kvms/$KVM_NAME/entries"
```

## Read a KVM entry

```sh
curl -X GET "https://$API_HOSTNAME/kvm-admin/v1/kvms/$KVM_NAME/entries/foo"
```

## Delete a KVM entry

```sh
curl -X DELETE "https://$API_HOSTNAME/kvm-admin/v1/kvms/$KVM_NAME/entries/foo"
```
