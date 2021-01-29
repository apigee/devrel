# KVM Admin Proxy

Depending on the Apigee deployment model you might have Managment APIs for
acessing and modifying the content of Apigee Key Value Maps (KVMs). In cases
where the access to the KVMs is not provided via the Apigee APIs you will need
to leverage policies to perform CRUD operations on the KVM contents.

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
export APIGEE_HYBRID_ORG=my-org-name
export APIGEE_HYBRID_ENV=test1
export KVM_NAME=my-kvm


curl -X POST \
    "https://apigee.googleapis.com/v1/organizations/${APIGEE_HYBRID_ORG}/environments/$APIGEE_HYBRID_ENV/keyvaluemaps" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"name\":\"$KVM_NAME\",\"encrypted\": true}"
```

## Create or Update a KVM entry

```sh
curl -X POST -H "Content-Type: application/json" -d '{ "name": "foo", "value": "bar" }' "https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/kvm-admin/v1/kvms/$KVM_NAME/entries"
```

## Read a KVM entry

```sh
curl -X GET "https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/kvm-admin/v1/kvms/$KVM_NAME/entries/foo"
```

## Delete a KVM entry

```sh
curl -X DELETE "https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/kvm-admin/v1/kvms/$KVM_NAME/entries/foo"
```
