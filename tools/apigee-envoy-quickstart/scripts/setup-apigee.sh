#!/bin/bash

# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

echo "Set up Apigee Product, for the endpoint targetted in K8s environment via Envoy proxy"

if [ "$PLATFORM" == 'opdk' ] || [ "$PLATFORM" == 'edge' ]
then
    curl -H "Authorization: ${TOKEN_TYPE} ${TOKEN}"   -H "Content-Type:application/json"   "${MGMT_HOST}/v1/organizations/${APIGEE_ORG}/apiproducts" -d \
    '{
    "name" : "envoy-adapter-product-2",
    "displayName" : "envoy-adapter-product-2",
    "approvalType" : "auto",
    "attributes" : [ {
        "name" : "access",
        "value" : "public"
    }, {
        "name" : "apigee-remote-service-targets",
        "value" : "httpbin.org"
    } ],
    "description" : "API Product for api proxies in Envoy",
    "environments": [
        "'${APIGEE_ENV}'"
    ],
    "apiResources" : [ "/headers" ]
    }'
else
    curl -H "Authorization: ${TOKEN_TYPE} ${TOKEN}"   -H "Content-Type:application/json"   "${MGMT_HOST}/v1/organizations/${APIGEE_ORG}/apiproducts" -d \
    '{
    "name": "envoy-adapter-product-2",
    "displayName": "envoy-adapter-product-2",
    "approvalType": "auto",
    "attributes": [
        {
        "name": "access",
        "value": "public"
        }
    ],
    "description": "API Product for api proxies in Envoy",
    "environments": [
        "'${APIGEE_ENV}'"
    ],
    "operationGroup": {
        "operationConfigs": [
        {
            "apiSource": "httpbin.apigee.svc.cluster.local",
            "operations": [
            {
                "resource": "/headers"
            }
            ],
            "quota": {}
        },
        {
            "apiSource": "httpbin.org",
            "operations": [
            {
                "resource": "/headers"
            }
            ],
            "quota": {}
        }
        ],
        "operationConfigType": "remoteservice"
    }
    }'
fi


echo "Set up Apigee Developer"

curl -H "Authorization: ${TOKEN_TYPE} ${TOKEN}"   -H "Content-Type:application/json"   "${MGMT_HOST}/v1/organizations/${APIGEE_ORG}/developers" -d \
    '{
    "email": "test-envoy@google.com",
    "firstName": "Test",
    "lastName": "Envoy",
    "userName": "pocenvoystarter"
    }'

echo 'Set up developer app for the Product having the endpoint targetted in K8s environment via Envoy proxy'

curl -H "Authorization: ${TOKEN_TYPE} ${TOKEN}"   -H "Content-Type:application/json"   "${MGMT_HOST}/v1/organizations/${APIGEE_ORG}/developers/test-envoy@google.com/apps" -d \
    '{
    "name":"envoy-adapter-app-2",
    "apiProducts": [
        "envoy-adapter-product-2"
        ]
    }'

