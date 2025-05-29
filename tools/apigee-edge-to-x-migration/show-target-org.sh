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
echo X_ORG="$X_ORG"

read -r -p "OK to proceed (Y/n)? " i
if [ "$i" != "Y" ]
then
  echo aborted
  exit 1
fi
echo; echo Proceeding...

TOKEN=$(gcloud auth print-access-token)

echo; echo Apps ================================
apigeecli -t "$TOKEN" --org="$X_ORG" apps list --expand | jq -r .app[].name

echo; echo Products ================================
apigeecli -t "$TOKEN" --org="$X_ORG" products list | jq -r .apiProduct[].name

echo; echo Developers ================================
apigeecli -t "$TOKEN" --org="$X_ORG" developers list | jq -r .developer[].email

echo; echo APIs ================================
apigeecli -t "$TOKEN" --org="$X_ORG" apis list | jq -r .proxies[].name

echo; echo Shared Flows ================================
apigeecli -t "$TOKEN" --org="$X_ORG" sharedflows list | jq -r .sharedFlows[].name

echo; echo ORG KVMS ================================
apigeecli -t "$TOKEN" --org="$X_ORG" kvms list | jq -r .[]

echo; echo ENV KVMS ================================
for ENV in $(apigeecli -t "$TOKEN" --org="$X_ORG" environments list | jq -r .[])
do
    echo ENV KVMS: "$ENV" ================================

    apigeecli -t "$TOKEN" --org="$X_ORG" --env="$ENV" kvms list | jq -r .[]
done

echo; echo PROXY KVMS ================================
PROXIES=$(apigeecli -t "$TOKEN" --org="$X_ORG" apis list | jq -r .proxies[].name)
for PROXY in $PROXIES
do
    KVMS=$(apigeecli -t "$TOKEN" --org="$X_ORG" --proxy="$PROXY" kvms list | jq -r .[])
    if [ "$KVMS" != "" ]
    then
        echo PROXY KVMS: "$PROXY" ================================
        for KVM in $KVMS
        do
            echo "$KVM"
        done
    fi
done

echo; echo TARGETSERVERS ================================
for ENV in $(apigeecli -t "$TOKEN" --org="$X_ORG" environments list | jq -r .[])
do
    echo ENV TARGETSERVERS: "$ENV" ================================

    apigeecli -t "$TOKEN" --org="$X_ORG" --env="$ENV" targetservers list | jq -r .[]
done
