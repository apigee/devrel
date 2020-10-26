#!/bin/sh
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

IFS='
'
COMPANIES=$(aac companies-get)

for COMPANY in $(echo "$COMPANIES" | jq -r '.[]'); do
  APPS=$(APIGEE_COMPANY=$COMPANY aac company-apps-get)
  for APP in $(echo "$APPS" | jq -r '.[]'); do
	  APIGEE_COMPANY=$COMPANY APIGEE_APP=$(echo "$APP" | sed 's/ /%20/g' ) aac company-app-delete
  done
  APIGEE_COMPANY=$COMPANY aac company-delete
done

DEVELOPERS=$(aac developers-get)

for DEVELOPER in $(echo "$DEVELOPERS" | jq -r '.[]'); do
  APPS=$(APIGEE_DEVELOPER=$DEVELOPER aac developer-apps-get)
  for APP in $(echo "$APPS" | jq -r '.[]'); do
	  APIGEE_DEVELOPER=$DEVELOPER APIGEE_APP=$(echo "$APP" | sed 's/ /%20/g') aac developer-app-delete
  done
  APIGEE_DEVELOPER=$DEVELOPER aac developer-delete
done

PRODUCTS=$(aac products-get)

for PRODUCT in $(echo "$PRODUCTS" | jq -r '.[]'); do
	APIGEE_PRODUCT=$(echo "$PRODUCT" | sed 's/ /%20/g') aac product-delete
done

DEPLOYMENTS=$(aac shared-flow-deployments-get)

# Undeploy all
for ENV in $(echo "$DEPLOYMENTS" | jq -r '.environment[].name'); do
  SHARED_FLOWS=$(echo "$DEPLOYMENTS" | jq -r ".environment[] | select(.name==(\"$ENV\")) | .aPIProxy")
  for SHARED_FLOW in $(echo "$SHARED_FLOWS" | jq -r ".[].name"); do
    REVISION=$(echo "$SHARED_FLOWS" | jq -r ".[] | select(.name==(\"$SHARED_FLOW\")) | .revision[0].name")
    APIGEE_SHARED_FLOW=$SHARED_FLOW APIGEE_REV=$REVISION APIGEE_ENV=$ENV aac shared-flow-deployment-delete
  done
done

# Delete all
for SHARED_FLOW in $(aac shared-flows-get | jq -r '.[]'); do 
  APIGEE_SHARED_FLOW=$SHARED_FLOW aac shared-flow-delete
done

DEPLOYMENTS=$(aac proxy-deployments-get)

# Undeploy all
for ENV in $(echo "$DEPLOYMENTS" | jq -r '.environment[].name'); do
  PROXIES=$(echo "$DEPLOYMENTS" | jq -r ".environment[] | select(.name==(\"$ENV\")) | .aPIProxy")
  for PROXY in $(echo "$PROXIES" | jq -r ".[].name"); do
    REVISION=$(echo "$PROXIES" | jq -r ".[] | select(.name==(\"$PROXY\")) | .revision[0].name")
    APIGEE_PROXY=$PROXY APIGEE_REV=$REVISION APIGEE_ENV=$ENV aac proxy-deployments-delete
  done
done

# Delete all
for PROXY in $(aac proxies-get | jq -r '.[]'); do 
  APIGEE_PROXY=$PROXY aac proxy-delete
done
