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

set_config_params() {
    echo "📝 Setting Config Parameters"
    export PROJECT_ID=$(gcloud config get-value "project")
    export DNS_NAME=hybridlab.danistrebel.com
    export REGION='europe-west1'
    export ZONE='europe-west1-b'
    export CLUSTER_NAME=apigee-hybrid-dev
    export APIGEE_CTL_VERSION='1.2.0'

    echo "🔧 Configuring GCP Project"
    gcloud config set project $PROJECT_ID
    gcloud config set compute/region $REGION
    gcloud config set compute/zone $ZONE
}

token() { echo -n "$(gcloud config config-helper --force-auth-refresh | grep access_token | grep -o -E '[^ ]+$')" ; }

function wait_for_ready(){
    local status=$1
    local action=$2
    local message=$3

    while true; do
        local signal=$(eval "$action")
        if [ $(echo $status) = "$signal" ]; then
            echo -e "\n$message"
            break
        fi
        echo -n "."
        sleep 5
    done
}


check_existing_apigee_org() {
  echo "🤔 Checking if the Apigee org '$PROJECT_ID' already exists".

  RESPONSE=$(curl -H "Authorization: Bearer $(token)" --silent \
    "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID")

  if [[ "$(jq .error <<< $RESPONSE)" == "null" ]]; then
    echo "🎉 Apigee org '$PROJECT_ID' already exists"
    export ORG_EXISTS=true
  else
    echo "🤷‍♀️ Apigee org '$PROJECT_ID' does not exist yet"
    export ORG_EXISTS=false

  fi
}

enable_all_apis() {
    echo "📝 Enabling all required APIs"
    if [ "$ORG_EXISTS" = false ]; then
      echo -n "⏳ Waiting for APIs to be enabled"
      gcloud services enable container.googleapis.com dns.googleapis.com apigee.googleapis.com cloudresourcemanager.googleapis.com compute.googleapis.com --project $PROJECT_ID
    else
      echo "(assuming they are already enabled)"
    fi
}

create_apigee_org() {

    echo "🚀 Create Apigee ORG - $PROJECT_ID"

    if [ "$ORG_EXISTS" = true ]; then
      echo "(skipping, already exists)"
      return
    fi

    curl -H "Authorization: Bearer $(token)" -X POST -H "content-type:application/json" \
    -d "{
        \"name\":\"$PROJECT_ID\",
        \"displayName\":\"$PROJECT_ID\",
        \"description\":\"Apigee Hybrid Org\",
        \"analyticsRegion\":\"$REGION\"
    }" \
    "https://apigee.googleapis.com/v1/organizations?parent=projects/$PROJECT_ID"

    echo -n "⏳ Waiting for Apigeectl Org Creation "
    wait_for_ready "\"$PROJECT_ID\"" 'curl --silent -H "Authorization: Bearer $(token)" -H "Content-Type: application/json"  https://apigee.googleapis.com/v1/organizations/$PROJECT_ID | jq ".name"' "Organization $PROJECT_ID is created."

    echo "✅ Created Env '$ENV_NAME'"
}

create_apigee_env() {

    ENV_NAME=$1

    echo "🚀 Create Apigee Env - $ENV_NAME"

    if [ "$ORG_EXISTS" = true ]; then
      echo "(skipping, already exists)"
      return
    fi

    curl -H "Authorization: Bearer $(token)" -X POST -H "content-type:application/json" \
    -d "{\"name\":\"$ENV_NAME\"}" \
    https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/environments

    echo -n "⏳ Waiting for Apigeectl Env Creation "
    wait_for_ready "\"$ENV_NAME\"" 'curl --silent -H "Authorization: Bearer $(token)" -H "Content-Type: application/json"  https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/environments/$ENV_NAME | jq ".name"' "Environment $ENV_NAME of Organization $PROJECT_ID is created."

    echo "✅ Created Env '$ENV_NAME'"
}

configure_network() {
    echo "🌐 Setup Networking"

    gcloud compute addresses create mart-ip --region $REGION
    gcloud compute addresses create api --region $REGION

    gcloud dns managed-zones create hybridlab --dns-name=$DNS_NAME --description=hybridlab

    export MART_IP=$(gcloud compute addresses list --format json --filter "name=mart-ip" | jq -r .[0].address)
    export INGRESS_IP=$(gcloud compute addresses list --format json --filter "name=api" | jq -r .[0].address)

    gcloud dns record-sets transaction start --zone=hybridlab

    gcloud dns record-sets transaction add "$INGRESS_IP" \
        --name=api.$DNS_NAME. --ttl=600 \
        --type=A --zone=hybridlab

    gcloud dns record-sets transaction add "$MART_IP" \
        --name=mart.$DNS_NAME. --ttl=600 \
        --type=A --zone=hybridlab

    gcloud dns record-sets transaction describe --zone=hybridlab
    gcloud dns record-sets transaction execute --zone=hybridlab

    export NAME_SERVER=$(gcloud dns managed-zones describe hybridlab --format="json" | jq -r .nameServers[0])
    echo "👋 Add this as an NS record for $DNS_NAME: $NAME_SERVER"
    echo "✅ Networking set up"
}

create_gke_cluster() {
    echo "🚀 Create GKE cluster"
    gcloud container clusters create $CLUSTER_NAME \
    --machine-type "n1-standard-4" --num-nodes "3" --enable-autoscaling --min-nodes "3" --max-nodes "6"

    gcloud container clusters get-credentials $CLUSTER_NAME

    kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole cluster-admin --user $(gcloud config get-value account)

    echo "✅ GKE set up"
}

download_apigee_ctl() {
    echo "Setup Apigeectl"

    curl -LO \
        https://storage.googleapis.com/apigee-public/apigee-hybrid-setup/$APIGEE_CTL_VERSION/apigeectl_linux_64.tar.gz

    tar xvzf apigeectl_linux_64.tar.gz
    rm apigeectl_linux_64.tar.gz
    mv apigeectl_*linux_64 apigeectl_$APIGEE_CTL_VERSION
    export APIGEECTL_HOME=$PWD/apigeectl_$APIGEE_CTL_VERSION
    echo "✅ Apigeectl set up in $APIGEECTL_HOME"
}

prepare_resources() {
    echo "Configure Apigee hybrid"

    mkdir -p hybrid-files
    cd hybrid-files
    export HYBRID_HOME=$PWD

    mkdir -p overrides
    mkdir  -p service-accounts
    mkdir  -p certs
    ln -s $APIGEECTL_HOME/tools tools
    ln -s $APIGEECTL_HOME/config config
    ln -s $APIGEECTL_HOME/templates templates
    ln -s $APIGEECTL_HOME/plugins plugins

    echo "📥 Copy Certs"
    gsutil cp -r gs://${PROJECT_ID}-certs/* ./certs
    echo "✅ Hybrid Config Setup"
}

create_sa() {
    for SA in mart cassandra udca metrics synchronizer logger
    do
        yes | $APIGEECTL_HOME/tools/create-service-account apigee-$SA $HYBRID_HOME/service-accounts
    done
}

install_runtime() {
    echo "Configure Overrides"
    cd $HYBRID_HOME
    cat << EOF > ./overrides/overrides.yaml
gcp:
  projectID: $PROJECT_ID
# Apigee org name.
org: $PROJECT_ID
# Kubernetes cluster name details
k8sCluster:
  name: $PROJECT_ID
  region: "$REGION"

virtualhosts:
  - name: default
    hostAliases: ["api.$DNS_NAME"]
    sslCertPath: ./certs/fullchain.pem
    sslKeyPath: ./certs/privkey.pem

    routingRules:
      - env: test
        # # base paths. Omit this if the base path is "/"
        # paths:
        #   - /v1/customers
        #   - /v1/customers2
        # # optional, connect timeout in seconds
        # connectTimeout: 57

envs:
  - name: test
    # Service accounts for sync and UDCA.
    serviceAccountPaths:
      synchronizer: ./service-accounts/$PROJECT_ID-apigee-synchronizer.json
      udca: ./service-accounts/$PROJECT_ID-apigee-udca.json

mart:
  hostAlias: "mart.$DNS_NAME"
  serviceAccountPath: ./service-accounts/$PROJECT_ID-apigee-mart.json
  sslCertPath: ./certs/fullchain.pem
  sslKeyPath: ./certs/privkey.pem

metrics:
  enabled: true
  serviceAccountPath: ./service-accounts/$PROJECT_ID-apigee-metrics.json

logger:
  enabled: true
  serviceAccountPath: ./service-accounts/$PROJECT_ID-apigee-logger.json

ingress:
  enableAccesslog: true
  runtime:
    loadBalancerIP: $INGRESS_IP
  mart:
    loadBalancerIP: $MART_IP
EOF


    $APIGEECTL_HOME/apigeectl init -f overrides/overrides.yaml
    echo -n "⏳ Waiting for Apigeectl init "
    wait_for_ready "0" '$APIGEECTL_HOME/apigeectl check-ready -f overrides/overrides.yaml; echo $?' "apigeectl init: done."

    $APIGEECTL_HOME/apigeectl apply -f overrides/overrides.yaml --dry-run=true
    $APIGEECTL_HOME/apigeectl apply -f overrides/overrides.yaml

    echo -n "⏳ Waiting for Apigeectl apply "
    wait_for_ready "0" '$APIGEECTL_HOME/apigeectl check-ready -f overrides/overrides.yaml; echo $?' "apigeectl apply: done."

    curl -X POST -H "Authorization: Bearer $(token)" \
    -H "Content-Type:application/json" \
    "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID:setSyncAuthorization" \
    -d "{\"identities\":[\"serviceAccount:apigee-synchronizer@$PROJECT_ID.iam.gserviceaccount.com\"]}"


    curl -X PUT \
    https://apigee.googleapis.com/v1/organizations/$PROJECT_ID \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $(token)" \
    -d "{
    \"name\" : \"$PROJECT_ID\",
    \"properties\" : {
        \"property\" : [ {
        \"name\" : \"features.hybrid.enabled\",
        \"value\" : \"true\"
        }, {
        \"name\" : \"features.mart.server.endpoint\",
        \"value\" : \"https://mart.$DNS_NAME\"
        } ]
    }
    }"


    echo "🎉🎉🎉 Hybrid installation completed!"
    echo "👋 Make sure you ad this as an NS record for $DNS_NAME: $NAME_SERVER"

}

