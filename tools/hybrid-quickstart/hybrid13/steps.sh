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
    echo "📝 Setting Config Parameters (Provide your own or defaults will be applied)"

    echo "🔧 Configuring GCP Project"
    PROJECT_ID=${PROJECT_ID:=$(gcloud config get-value "project")}
    export PROJECT_ID
    gcloud config set project "$PROJECT_ID"

    export REGION=${REGION:='europe-west1'}
    gcloud config set compute/region $REGION

    export ZONE=${ZONE:='europe-west1-c'}
    gcloud config set compute/zone $ZONE

    echo "🔧 Configuring Apigee hybrid"
    export DNS_NAME=${DNS_NAME:="$PROJECT_ID.example.com"}
    export CLUSTER_NAME=${CLUSTER_NAME:=apigee-hybrid}
    export ENV_GROUP_NAME=${ENV_GROUP_NAME:=default}
    export ENV_NAME=${ENV_NAME:=test}

    export APIGEE_CTL_VERSION='1.3.3'
    export KPT_VERSION='v0.34.0'

    OS_NAME=$(uname -s)
    if [[ "$OS_NAME" == "Linux" ]]; then
      echo "🐧 Using Linux binaries"
      export APIGEE_CTL='apigeectl_linux_64.tar.gz'
      export ISTIO_ASM_CLI='istio-1.6.11-asm.1-linux.tar.gz'
      export KPT_BINARY='kpt_linux_amd64-0.34.0.tar.gz'
    elif [[ "$OS_NAME" == "Darwin" ]]; then
      echo "🍏 Using macOS binaries"
      export APIGEE_CTL='apigeectl_mac_64.tar.gz'
      export ISTIO_ASM_CLI='istio-1.6.11-asm.1-osx.tar.gz'
      export KPT_BINARY='kpt_darwin_amd64-0.34.0.tar.gz'
    else
      echo "💣 Only Linux and macOS are supported at this time. You seem to be running on $OS_NAME."
      exit 2
    fi

    echo "🔧 Setting derived config parameters"
    PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
    export PROJECT_NUMBER
    export WORKLOAD_POOL="${PROJECT_ID}.svc.id.goog"
    export MESH_ID="proj-${PROJECT_NUMBER}"

    # these will be set if the steps are run in order
    INGRESS_IP=$(gcloud compute addresses list --format json --filter "name=apigee-ingress-loadbalancer" --format="get(address)")
    export INGRESS_IP
    NAME_SERVER=$(gcloud dns managed-zones describe apigee-dns-zone --format="json" --format="get(nameServers[0])" 2>/dev/null)
    export NAME_SERVER

    export QUICKSTART_ROOT="${QUICKSTART_ROOT:=$PWD}"
    export QUICKSTART_TOOLS="$QUICKSTART_ROOT/tools"
    export APIGEECTL_HOME=$QUICKSTART_TOOLS/apigeectl/apigeectl_$APIGEE_CTL_VERSION
    export HYBRID_HOME=$QUICKSTART_ROOT/hybrid-files

    echo "Running hybrid quickstart script from: $QUICKSTART_ROOT"
}

token() { echo -n "$(gcloud config config-helper --force-auth-refresh | grep access_token | grep -o -E '[^ ]+$')" ; }

function wait_for_ready(){
    local expected_status=$1
    local action=$2
    local message=$3
    local max_iterations=120 # 10min
    local iterations=0
    local signal

    echo -e "Start: $(date)\n"

    while true; do
        ((iterations++))

        signal=$(eval "$action")
        if [ "$expected_status" = "$signal" ]; then
            echo -e "\n$message"
            break
        fi

        if [ "$iterations" -ge "$max_iterations" ]; then
          echo "Wait Timeout"
          exit 1
        fi
        echo -n "."
        sleep 5
    done
}


check_existing_apigee_resource() {
  RESOURCE_URI=$1

  echo "🤔 Checking if the Apigee resource '$RESOURCE_URI' already exists".

  RESPONSE=$(curl -H "Authorization: Bearer $(token)" --silent "$RESOURCE_URI")

  if [[ $RESPONSE == *"error"* ]]; then
    echo "🤷‍♀️ Apigee resource '$RESOURCE_URI' does not exist yet"
    return 1
  else
    echo "🎉 Apigee resource '$RESOURCE_URI' already exists"
    return 0
  fi
}

enable_all_apis() {

  PROJECT_ID=${PROJECT_ID:=$(gcloud config get-value "project")}

  echo "📝 Enabling all required APIs in GCP project \"$PROJECT_ID\""
  
  # Assuming we already enabled the APIs if the Apigee Org exists
  if check_existing_apigee_resource "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID" ; then
    echo "(assuming APIs are already enabled)"
    return
  fi
  echo -n "⏳ Waiting for APIs to be enabled"

  gcloud services enable \
    anthos.googleapis.com \
    apigee.googleapis.com \
    apigeeconnect.googleapis.com \
    cloudresourcemanager.googleapis.com \
    cloudtrace.googleapis.com \
    compute.googleapis.com \
    container.googleapis.com \
    dns.googleapis.com \
    gkeconnect.googleapis.com \
    gkehub.googleapis.com \
    iamcredentials.googleapis.com \
    logging.googleapis.com \
    meshca.googleapis.com \
    meshconfig.googleapis.com \
    meshtelemetry.googleapis.com \
    monitoring.googleapis.com \
    --project "$PROJECT_ID"
}

create_apigee_org() {

    echo "🚀 Create Apigee ORG - $PROJECT_ID"

    if check_existing_apigee_resource "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID" ; then
      echo "(skipping org creation, already exists)"
      return
    fi

    curl -H "Authorization: Bearer $(token)" -X POST -H "content-type:application/json" \
    -d "{
        \"name\":\"$PROJECT_ID\",
        \"displayName\":\"$PROJECT_ID\",
        \"description\":\"Apigee Hybrid Org\",
        \"analyticsRegion\":\"$REGION\",
        \"runtimeType\":\"HYBRID\",
        \"properties\" : {
          \"property\" : [ {
            \"name\" : \"features.hybrid.enabled\",
            \"value\" : \"true\"
          }, {
            \"name\" : \"features.mart.connect.enabled\",
            \"value\" : \"true\"
          } ]
        }
      }" \
    "https://apigee.googleapis.com/v1/organizations?parent=projects/$PROJECT_ID"

    echo -n "⏳ Waiting for Apigeectl Org Creation "
    wait_for_ready "0" "curl --silent -H \"Authorization: Bearer $(token)\" -H \"Content-Type: application/json\" https://apigee.googleapis.com/v1/organizations/$PROJECT_ID | grep -q \"subscriptionType\"; echo \$?" "Organization $PROJECT_ID is created."

    echo "✅ Created Org '$PROJECT_ID'"
}

create_apigee_env() {

    ENV_NAME=$1

    echo "🚀 Create Apigee Env - $ENV_NAME"

    if check_existing_apigee_resource "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/environments/$ENV_NAME"; then
      echo "(skipping, env already exists)"
      return
    fi

    curl -H "Authorization: Bearer $(token)" -X POST -H "content-type:application/json" \
      -d "{\"name\":\"$ENV_NAME\"}" \
      "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/environments"

    echo -n "⏳ Waiting for Apigeectl Env Creation "
    wait_for_ready "0" "curl --silent -H \"Authorization: Bearer $(token)\" -H \"Content-Type: application/json\"  https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/environments/$ENV_NAME | grep -q \"$ENV_NAME\"; echo \$?" "Environment $ENV_NAME of Organization $PROJECT_ID is created."

    echo "✅ Created Env '$ENV_NAME'"
}

create_apigee_envgroup() {

    ENV_GROUP_NAME=$1

    echo "🚀 Create Apigee Env Group - $ENV_GROUP_NAME"

    if check_existing_apigee_resource "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/envgroups/$ENV_GROUP_NAME"; then
      echo "(skipping, envgroup already exists)"
      return
    fi

    curl -H "Authorization: Bearer $(token)" -X POST -H "content-type:application/json" \
      -d "{
        \"name\":\"$ENV_GROUP_NAME\", 
        \"hostnames\":[\"api.$DNS_NAME\"], 
      }" \
      "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/envgroups"

    echo -n "⏳ Waiting for Apigeectl Env Creation"
    wait_for_ready "0" "curl --silent -H \"Authorization: Bearer $(token)\" -H \"Content-Type: application/json\" https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/envgroups/$ENV_GROUP_NAME | grep -q $ENV_GROUP_NAME; echo \$?" "Environment Group $ENV_GROUP_NAME of Organization $PROJECT_ID is created."

    echo "✅ Created Env Group '$ENV_GROUP_NAME'"
}

add_env_to_envgroup() {
  ENV_NAME=$1
  ENV_GROUP_NAME=$2

  echo "🚀 Adding Env $ENV_NAME to Env Group $ENV_GROUP_NAME"

  local ENV_GROUPS_ATTACHMENT_URI
  ENV_GROUPS_ATTACHMENT_URI="https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/envgroups/$ENV_GROUP_NAME/attachments"

  

  if curl --silent -H "Authorization: Bearer $(token)" -H "content-type:application/json" "$ENV_GROUPS_ATTACHMENT_URI" | grep -q "\"environment\": \"$ENV_NAME\""; then
    echo "(skipping, envgroup assignment already exists)"
    return
  else
    curl -q -H "Authorization: Bearer $(token)" -X POST -H "content-type:application/json" \
      -d '{ "environment": "'"$ENV_NAME"'" }' "$ENV_GROUPS_ATTACHMENT_URI"
  fi
  
  echo "✅ Added Env $ENV_NAME to Env Group $ENV_GROUP_NAME"
}

configure_network() {
    echo "🌐 Setup Networking"

    gcloud compute addresses create apigee-ingress-loadbalancer --region $REGION

    gcloud dns managed-zones create apigee-dns-zone --dns-name="$DNS_NAME" --description=apigee-dns-zone

    INGRESS_IP=$(gcloud compute addresses list --format json --filter "name=apigee-ingress-loadbalancer" --format="get(address)")
    export INGRESS_IP

    gcloud dns record-sets transaction start --zone=apigee-dns-zone

    gcloud dns record-sets transaction add "$INGRESS_IP" \
        --name="api.$DNS_NAME." --ttl=600 \
        --type=A --zone=apigee-dns-zone

    gcloud dns record-sets transaction describe --zone=apigee-dns-zone
    gcloud dns record-sets transaction execute --zone=apigee-dns-zone

    NAME_SERVER=$(gcloud dns managed-zones describe apigee-dns-zone --format="json" --format="get(nameServers[0])")
    export NAME_SERVER
    echo "👋 Add this as an NS record for $DNS_NAME: $NAME_SERVER"
    echo "✅ Networking set up"
}

create_gke_cluster() {
    echo "🚀 Create GKE cluster"

    gcloud container clusters create $CLUSTER_NAME \
      --machine-type "e2-standard-4" \
      --num-nodes "4" \
      --enable-autoscaling --min-nodes "3" --max-nodes "6" \
      --labels mesh_id="$MESH_ID" \
      --workload-pool "$WORKLOAD_POOL" \
      --enable-stackdriver-kubernetes

    gcloud container clusters get-credentials $CLUSTER_NAME

    kubectl create clusterrolebinding cluster-admin-binding \
      --clusterrole cluster-admin --user "$(gcloud config get-value account)"

    echo "✅ GKE set up"
}


install_asm_and_certmanager() {

  echo "👩🏽‍💼 Creating Cert Manager"
  kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.16.1/cert-manager.yaml

  echo "🤹‍♂️ Initialize ASM"

   curl --request POST \
    --header "Authorization: Bearer $(token)" \
    --data '' \
    "https://meshconfig.googleapis.com/v1alpha1/projects/${PROJECT_ID}:initialize"

  echo "🔌 Registering Cluster with Anthos Hub"
  SERVICE_ACCOUNT_NAME="$CLUSTER_NAME-anthos"

  # fail silently if the account already exists
  gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME 2>/dev/null

  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
   --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
   --role="roles/gkehub.connect"

  SERVICE_ACCOUNT_KEY_PATH="/tmp/$SERVICE_ACCOUNT_NAME.json"

  gcloud iam service-accounts keys create $SERVICE_ACCOUNT_KEY_PATH \
   --iam-account="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

  gcloud container hub memberships register $CLUSTER_NAME \
    --gke-cluster="$ZONE/$CLUSTER_NAME" \
    --service-account-key-file="$SERVICE_ACCOUNT_KEY_PATH"

  rm $SERVICE_ACCOUNT_KEY_PATH

  echo "🏗️ Installing Anthos Service Mesh"
  mkdir -p "$QUICKSTART_TOOLS"/istio-asm
  curl -L -o "$QUICKSTART_TOOLS/istio-asm/istio-asm.tar.gz" "https://storage.googleapis.com/gke-release/asm/${ISTIO_ASM_CLI}"
  tar xzf "$QUICKSTART_TOOLS/istio-asm/istio-asm.tar.gz" -C "$QUICKSTART_TOOLS/istio-asm"
  mv "$QUICKSTART_TOOLS"/istio-asm/istio-*/* "$QUICKSTART_TOOLS/istio-asm/."

  echo "🩹 Patching the ASM Config"
  mkdir -p "$QUICKSTART_TOOLS"/kpt
  curl -L -o "$QUICKSTART_TOOLS/kpt/kpt.tar.gz" "https://github.com/GoogleContainerTools/kpt/releases/download/${KPT_VERSION}/${KPT_BINARY}"
  tar xzf "$QUICKSTART_TOOLS/kpt/kpt.tar.gz" -C "$QUICKSTART_TOOLS/kpt"

  "$QUICKSTART_TOOLS"/kpt/kpt pkg get \
    https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git/asm@release-1.6-asm "$QUICKSTART_TOOLS"/kpt/asm

  "$QUICKSTART_TOOLS"/kpt/kpt cfg set "$QUICKSTART_TOOLS"/kpt/asm gcloud.container.cluster "$CLUSTER_NAME"
  "$QUICKSTART_TOOLS"/kpt/kpt cfg set "$QUICKSTART_TOOLS"/kpt/asm gcloud.core.project "$PROJECT_ID"
  "$QUICKSTART_TOOLS"/kpt/kpt cfg set "$QUICKSTART_TOOLS"/kpt/asm gcloud.compute.location "$ZONE"
  "$QUICKSTART_TOOLS"/kpt/kpt cfg set "$QUICKSTART_TOOLS"/kpt/asm gcloud.project.environProjectNumber "$MESH_ID"
  "$QUICKSTART_TOOLS"/kpt/kpt cfg set "$QUICKSTART_TOOLS"/kpt/asm anthos.servicemesh.profile "asm-gcp"

  "$QUICKSTART_TOOLS"/istio-asm/bin/istioctl install -f "$QUICKSTART_TOOLS"/kpt/asm/cluster/istio-operator.yaml \
    --revision=asm-1611-1 \
    --set values.gateways.istio-ingressgateway.loadBalancerIP="$INGRESS_IP" \
    --set meshConfig.enableAutoMtls=false \
    --set meshConfig.accessLogFile=/dev/stdout \
    --set meshConfig.accessLogEncoding=1 \
    --set meshConfig.accessLogFormat='{"start_time":"%START_TIME%","remote_address":"%DOWNSTREAM_DIRECT_REMOTE_ADDRESS%","user_agent":"%REQ(USER-AGENT)%","host":"%REQ(:AUTHORITY)%","request":"%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%","request_time":"%DURATION%","status":"%RESPONSE_CODE%","status_details":"%RESPONSE_CODE_DETAILS%","bytes_received":"%BYTES_RECEIVED%","bytes_sent":"%BYTES_SENT%","upstream_address":"%UPSTREAM_HOST%","upstream_response_flags":"%RESPONSE_FLAGS%","upstream_response_time":"%RESPONSE_DURATION%","upstream_service_time":"%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%","upstream_cluster":"%UPSTREAM_CLUSTER%","x_forwarded_for":"%REQ(X-FORWARDED-FOR)%","request_method":"%REQ(:METHOD)%","request_path":"%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%","request_protocol":"%PROTOCOL%","tls_protocol":"%DOWNSTREAM_TLS_VERSION%","request_id":"%REQ(X-REQUEST-ID)%","sni_host":"%REQUESTED_SERVER_NAME%","apigee_dynamic_data":"%DYNAMIC_METADATA(envoy.lua)%"}'

  echo "✅ ASM installed"
}

download_apigee_ctl() {
    echo "📥 Setup Apigeectl"

    mkdir -p "$QUICKSTART_TOOLS"/apigeectl
    curl -L \
      -o "$QUICKSTART_TOOLS"/apigeectl/apigeectl.tar.gz \
      "https://storage.googleapis.com/apigee-public/apigee-hybrid-setup/$APIGEE_CTL_VERSION/$APIGEE_CTL"

    tar xvzf "$QUICKSTART_TOOLS"/apigeectl/apigeectl.tar.gz -C "$QUICKSTART_TOOLS"/apigeectl
    rm "$QUICKSTART_TOOLS"/apigeectl/apigeectl.tar.gz
    mkdir -p "$APIGEECTL_HOME"
    mv "$QUICKSTART_TOOLS"/apigeectl/apigeectl_*_64/* "$APIGEECTL_HOME"
    rm -d "$QUICKSTART_TOOLS"/apigeectl/apigeectl_*_64
    echo "✅ Apigeectl set up in $APIGEECTL_HOME"
}

prepare_resources() {
    echo "🛠️ Configure Apigee hybrid"

    if [ -d "$HYBRID_HOME" ]; then rm -rf "$HYBRID_HOME"; fi
    mkdir -p "$HYBRID_HOME"

    mkdir -p "$HYBRID_HOME/overrides"
    mkdir  -p "$HYBRID_HOME/service-accounts"
    ln -s "$APIGEECTL_HOME/tools" "$HYBRID_HOME/tools"
    ln -s "$APIGEECTL_HOME/config" "$HYBRID_HOME/config"
    ln -s "$APIGEECTL_HOME/templates" "$HYBRID_HOME/templates"
    ln -s "$APIGEECTL_HOME/plugins" "$HYBRID_HOME/plugins"

    create_self_signed_cert "$DNS_NAME" "$PROJECT_ID-$ENV_GROUP_NAME"
    echo "✅ Hybrid Config Setup"
}

create_self_signed_cert() {
  DNS_NAME=$1
  SECRET_NAME=$2

  echo "🙈 Creating self-signed cert - $SECRET_NAME"
  mkdir  -p "$HYBRID_HOME/certs"
  openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj "/CN=$DNS_NAME/O=Apigee Quickstart" -keyout "$HYBRID_HOME/certs/$DNS_NAME.key" -out "$HYBRID_HOME/certs/$DNS_NAME.crt"
  openssl req -out "$HYBRID_HOME/certs/api.$DNS_NAME.csr" -newkey rsa:2048 -nodes -keyout "$HYBRID_HOME/certs/api.$DNS_NAME.key" -subj "/CN=api.$DNS_NAME/O=Apigee Quickstart"
  openssl x509 -req -days 365 -CA "$HYBRID_HOME/certs/$DNS_NAME.crt" -CAkey "$HYBRID_HOME/certs/$DNS_NAME.key" -set_serial 0 -in "$HYBRID_HOME/certs/api.$DNS_NAME.csr" -out "$HYBRID_HOME/certs/api.$DNS_NAME.crt"
  cat "$HYBRID_HOME/certs/api.$DNS_NAME.crt" "$HYBRID_HOME/certs/$DNS_NAME.crt" > "$HYBRID_HOME/certs/api.$DNS_NAME.fullchain.crt"
  
  kubectl create -n istio-system secret generic "$SECRET_NAME"  \
    --from-file=key="$HYBRID_HOME/certs/api.$DNS_NAME.key" \
    --from-file=cert="$HYBRID_HOME/certs/api.$DNS_NAME.fullchain.crt" --dry-run -o yaml | 
  kubectl apply -f -
}

create_sa() {
    for SA in mart cassandra udca metrics synchronizer logger watcher
    do
      yes | "$APIGEECTL_HOME"/tools/create-service-account "apigee-$SA" "$HYBRID_HOME/service-accounts"
    done
}

install_runtime() {
    echo "Configure Overrides"

    cat << EOF > "$HYBRID_HOME"/overrides/overrides.yaml
gcp:
  projectID: $PROJECT_ID
  region: "$REGION"
# Apigee org name.
org: $PROJECT_ID
# Kubernetes cluster name details
k8sCluster:
  name: $CLUSTER_NAME
  region: "$REGION"

virtualhosts:
  - name: $ENV_GROUP_NAME
    sslSecret: $PROJECT_ID-$ENV_GROUP_NAME

instanceID: "$PROJECT_ID-$(date +%s)"

envs:
  - name: $ENV_NAME
    serviceAccountPaths:
      synchronizer: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-synchronizer.json"
      udca: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-udca.json"

mart:
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-mart.json"

connectAgent:
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-mart.json"

metrics:
  enabled: true
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-metrics.json"

watcher:
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-watcher.json"
EOF
    pushd "$HYBRID_HOME" || return # because apigeectl uses pwd-relative paths
    mkdir -p "$HYBRID_HOME"/generated
    "$APIGEECTL_HOME"/apigeectl init -f "$HYBRID_HOME"/overrides/overrides.yaml --print-yaml > "$HYBRID_HOME"/generated/apigee-init.yaml
    echo -n "⏳ Waiting for Apigeectl init "
    wait_for_ready "0" "$APIGEECTL_HOME/apigeectl check-ready -f $HYBRID_HOME/overrides/overrides.yaml > /dev/null  2>&1; echo \$?" "apigeectl init: done."

    "$APIGEECTL_HOME"/apigeectl apply -f "$HYBRID_HOME"/overrides/overrides.yaml --dry-run=true
    "$APIGEECTL_HOME"/apigeectl apply -f "$HYBRID_HOME"/overrides/overrides.yaml --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml

    echo -n "⏳ Waiting for Apigeectl apply "
    wait_for_ready "0" "$APIGEECTL_HOME/apigeectl check-ready -f $HYBRID_HOME/overrides/overrides.yaml > /dev/null  2>&1; echo \$?" "apigeectl apply: done."

    popd || return

    curl -X POST -H "Authorization: Bearer $(token)" \
    -H "Content-Type:application/json" \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}:setSyncAuthorization" \
    -d "{\"identities\":[\"serviceAccount:apigee-synchronizer@${PROJECT_ID}.iam.gserviceaccount.com\"]}"

    echo "🎉🎉🎉 Hybrid installation completed!"

}

deploy_example_proxy() {
  echo "🦄 Deploy Sample Proxy"
  
  (cd "$QUICKSTART_ROOT/example-proxy" && zip -r apiproxy.zip apiproxy/*) 

  PROXY_REV=$(curl -X POST \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}/apis?action=import&name=httpbin-v0&validate=true" \
    -H "Authorization: Bearer $(token)" \
    -H "Content-Type: multipart/form-data" \
    -F "zipFile=@$QUICKSTART_ROOT/example-proxy/apiproxy.zip" | grep '"revision": "[^"]*' | cut -d'"' -f4)
  
  rm "$QUICKSTART_ROOT/example-proxy/apiproxy.zip"

  curl -X POST \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}/environments/$ENV_NAME/apis/httpbin-v0/revisions/${PROXY_REV}/deployments?override=true" \
    -H "Authorization: Bearer $(token)"
  
  echo "✅ Sample Proxy Deployed"

  echo "🤓 Try without DNS (first deployment takes a few seconds. Relax and breathe!):"
  echo "curl --cacert $QUICKSTART_ROOT/hybrid-files/certs/$DNS_NAME.crt --resolve api.$DNS_NAME:443:$INGRESS_IP https://api.$DNS_NAME/httpbin/v0/anything"

  echo "👋 To reach it via the FQDN: Make sure you add this as an NS record for $DNS_NAME: $NAME_SERVER"
}

delete_apigee_keys() {
  for SA in mart cassandra udca metrics synchronizer logger watcher
  do
    delete_sa_keys "apigee-${SA}"
  done
}

delete_sa_keys() {
  SA=$1
  for SA_KEY_NAME in $(gcloud iam service-accounts keys list --iam-account="${SA}@${PROJECT_ID}.iam.gserviceaccount.com" --format="get(name)")
  do
    gcloud iam service-accounts keys delete "$SA_KEY_NAME" --iam-account="$SA@$PROJECT_ID.iam.gserviceaccount.com" -q
  done
}
