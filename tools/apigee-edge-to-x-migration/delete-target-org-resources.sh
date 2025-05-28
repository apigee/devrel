#! /bin/bash

# Copyright 2025 Google LLC
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

gcloud config get project
echo X_ORG=$X_ORG

echo '*******************************************'
echo WARNING WARNING WARNING
echo This will attempt to remove all resources from the org, not just the ones that were imported!
echo WARNING WARNING WARNING
echo '*******************************************'

read -p "OK to proceed (Y/n)? " i
if [ "$i" != "Y" ]
then
  echo aborted
  exit 1
fi
echo Proceeding...

# access tokens have a 60 minute expiry but using application default token and --default-token does not
# gcloud auth application-default login
echo; echo GET $X_ORG
apigeecli --default-token organizations get --org=$X_ORG
if [ "$?" != "0" ]
then
  echo $X_ORG not found
  exit 1
fi

echo; echo Cleaning Developers also removes Apps
for DEVELOPER in $(apigeecli --default-token --org=$X_ORG developers list | jq -r .developer[].email)
do 
    echo DEVELOPER: $DEVELOPER
    apigeecli --default-token --org=$X_ORG developers delete --email=$DEVELOPER
done

# Products can have a space in the name so URL encode
echo; echo Cleaning API Products
PRODUCTS=$(apigeecli --default-token --org=$X_ORG products list | jq -r .apiProduct[].name)
while IFS= read -r PRODUCT; do
    ENCODED_PRODUCT=$(jq -r -n --arg str "$PRODUCT" '$str | @uri')

    echo PRODUCT: $PRODUCT $ENCODED_PRODUCT
    apigeecli --default-token --org=$X_ORG products delete --name=$ENCODED_PRODUCT

done <<< "$PRODUCTS"

echo; echo Cleaning Proxies
for API in $(apigeecli --default-token --org=$X_ORG apis list | jq -r .proxies[].name)
do 
    echo API: $API
    apigeecli --default-token --org=$X_ORG apis delete --name=$API
done

echo; echo Cleaning SharedFlows
for SF in $(apigeecli --default-token --org=$X_ORG sharedflows list | jq -r .sharedFlows[].name)
do 
    echo SF: $SF
    apigeecli --default-token --org=$X_ORG sharedflows delete --name=$SF
done

echo; echo Cleaning ORG KVMs
for KVM in $(apigeecli --default-token --org=$X_ORG kvms list | jq -r .[])
do 
    echo KVM: $KVM
    apigeecli --default-token --org=$X_ORG kvms delete --name=$KVM
done

echo; echo Cleaning ENV KVMs
for ENV in $(apigeecli --default-token --org=$X_ORG environments list | jq -r .[])
do
    echo ENV: $ENV

    for KVM in $(apigeecli --default-token --org=$X_ORG --env=$ENV kvms list | jq -r .[])
    do 
        echo ENV KVM: $KVM
        apigeecli --default-token --org=$X_ORG --env=$ENV kvms delete --name=$KVM
    done
done

PROXIES=$(apigeecli --default-token --org=$X_ORG apis list | jq -r .proxies[].name)
for PROXY in $PROXIES
do
    KVMS=$(apigeecli --default-token --org=$X_ORG --proxy=$PROXY kvms list | jq -r .[])
    if [ "$KVMS" != "" ]
    then
      echo PROXY KVMS: $PROXY ================================
      for KVM in $KVMS
        do 
            echo PROXY KVMS: $PROXY $KVM ================================
            # echo apigeecli --org=$X_ORG --proxy=$PROXY kvms delete --name=$KVM
            apigeecli --default-token --org=$X_ORG --proxy=$PROXY kvms delete --name=$KVM
        done
    fi
done

echo TARGETSERVERS ================================
for ENV in $(apigeecli --default-token --org=$X_ORG environments list | jq -r .[])
do
    echo ENV TARGETSERVERS: $ENV ================================

    for TS in $(apigeecli --default-token --org=$X_ORG --env=$ENV targetservers list | jq -r .[])
    do
        echo TS: $TS
        # echo apigeecli --org=$X_ORG --env=$ENV targetservers delete --name=$TS
        apigeecli --default-token --org=$X_ORG --env=$ENV targetservers delete --name=$TS
    done
done
