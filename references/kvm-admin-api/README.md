# KVM Admin Proxy

Depending on the Apigee deployment model you might have Managment APIs for
acessing and modifying the content of Apigee Key Value Maps (KVMs). In cases
where the access to the KVMs is not provided via the Apigee APIs you will need
to leverage policies to perform CRUD operations on the KVM contents.

This project provides a reference implementation for how to read, write and
delete entries within KVMs inside Apigee regardless of the deploment model and
the existance of KVM managment APIs.

## Create a KVM entry

```sh
# dynamic kvm name
curl -X PUT -H "Content-Type: application/json" -d '{ "value": "bar" }' https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/kvm-admin/v1/kvms/sample-kvm/entries/foo

# default kvm
curl -X PUT -H "Content-Type: application/json" -d '{ "value": "bar" }' https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/kvm-admin/v1/entries/foo
```

## Read a KVM entry
```sh
# dynamic kvm name
curl -X GET https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/kvm-admin/v1/kvms/sample-kvm/entries/foo

# default kvm
curl -X GET https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/kvm-admin/v1/entries/foo
```

## Delete a KVM entry
```sh
# dynamic kvm name
curl -X DELETE   https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/kvm-admin/v1/kvms/sample-kvm/entries/foo

# default kvm
curl -X DELETE   https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/kvm-admin/v1/entries/foo
```

