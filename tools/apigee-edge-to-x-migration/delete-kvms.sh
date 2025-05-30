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

# Usage: ${APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR}/clean_apps.sh

gcloud config get project
echo X_ORG="$X_ORG"

echo '*******************************************'
echo WARNING WARNING WARNING
echo This will attempt to remove all KVMs at the org and envs level, not just the ones that were imported!
echo WARNING WARNING WARNING
echo '*******************************************'

read -r -p "OK to proceed (Y/n)? " i
if [ "$i" != "Y" ]
then
  echo aborted
  exit 1
fi
echo Proceeding...

TOKEN=$(gcloud auth print-access-token)

for KVM in $(apigeecli -t "$TOKEN" --org="$ORG" kvms list | jq -r .[])
do 
    echo KVM: "$KVM"
    apigeecli -t "$TOKEN" --org="$ORG" kvms delete --name="$KVM"
done

for ENV in $(apigeecli -t "$TOKEN" --org="$ORG" environments list | jq -r .[])
do
    echo ENV KVMS: "$ENV" ================================

    for KVM in $(apigeecli -t "$TOKEN" --org="$ORG" --env="$ENV" kvms list | jq -r .[])
    do 
        echo "$ENV" KVM: "$KVM"
        apigeecli -t "$TOKEN" --org="$ORG" --env="$ENV" kvms delete --name="$KVM" 
    done
done

echo; echo PROXY KVMS ================================
PROXIES=$(apigeecli -t "$TOKEN" --org="$ORG" apis list | jq -r .proxies[].name)
for PROXY in $PROXIES
do
    KVMS=$(apigeecli -t "$TOKEN" --org="$ORG" --proxy="$PROXY" kvms list | jq -r .[])
    if [ "$KVMS" != "" ]
    then
        echo PROXY KVMS: "$PROXY" ================================
        for KVM in $KVMS
        do
            echo "$KVM"
            apigeecli -t "$TOKEN" --org="$ORG" --proxy="$PROXY" kvms delete --name="$KVM"
        done
    fi
done
