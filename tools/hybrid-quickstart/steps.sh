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

    export AX_REGION=${AX_REGION:='europe-west1'}

    export REGION=${REGION:='europe-west1'}
    gcloud config set compute/region $REGION

    export ZONE=${ZONE:='europe-west1-c'}
    gcloud config set compute/zone $ZONE

    export INGRESS_TYPE=${INGRESS_TYPE:='external'} # internal|external

    echo "🔧 Configuring Apigee hybrid"
    export DNS_NAME=${DNS_NAME:="$PROJECT_ID.example.com"}
    export GKE_CLUSTER_NAME=${GKE_CLUSTER_NAME:=apigee-hybrid}
    export GKE_CLUSTER_MACHINE_TYPE=${GKE_CLUSTER_MACHINE_TYPE:=e2-standard-4}

    export APIGEE_CTL_VERSION='1.4.0'
    export KPT_VERSION='v0.34.0'
    export CERT_MANAGER_VERSION='v1.1.0'

    OS_NAME=$(uname -s)
    if [[ "$OS_NAME" == "Linux" ]]; then
      echo "🐧 Using Linux binaries"
      export APIGEE_CTL='apigeectl_linux_64.tar.gz'
      export KPT_BINARY='kpt_linux_amd64-0.34.0.tar.gz'
      export JQ_VERSION='jq-1.6/jq-linux64'
    elif [[ "$OS_NAME" == "Darwin" ]]; then
      echo "🍏 Using macOS binaries"
      export APIGEE_CTL='apigeectl_mac_64.tar.gz'
      export KPT_BINARY='kpt_darwin_amd64-0.34.0.tar.gz'
      export JQ_VERSION='jq-1.6/jq-osx-amd64'
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
    INGRESS_IP=$(gcloud compute addresses list --format json --filter "name=apigee-ingress-ip" --format="get(address)" || echo "")
    export INGRESS_IP
    NAME_SERVER=$(gcloud dns managed-zones describe apigee-dns-zone --format="json" --format="get(nameServers[0])" 2>/dev/null || echo "")
    export NAME_SERVER

    export QUICKSTART_ROOT="${QUICKSTART_ROOT:=$PWD}"
    export QUICKSTART_TOOLS="$QUICKSTART_ROOT/tools"
    export APIGEECTL_HOME=$QUICKSTART_TOOLS/apigeectl/apigeectl_$APIGEE_CTL_VERSION
    export HYBRID_HOME=$QUICKSTART_ROOT/hybrid-files

    echo "Running hybrid quickstart script from: $QUICKSTART_ROOT"
}

token() { echo -n "$(gcloud config config-helper --force-auth-refresh | grep access_token | grep -o -E '[^ ]+$')" ; }

function wait_for_ready(){
    local expected_output=$1
    local action=$2
    local message=$3
    local max_iterations=120 # 10min
    local iterations=0
    local actual_out

    echo -e "Start: $(date)\n"

    while true; do
        iterations="$((iterations+1))"

        actual_out=$(bash -c "$action" || echo "error code $?")
        if [ "$expected_output" = "$actual_out" ]; then
            echo -e "\n$message"
            break
        fi

        if [ "$iterations" -ge "$max_iterations" ]; then
          echo "Wait timed out"
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
    pubsub.googleapis.com \
    stackdriver.googleapis.com \
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
        \"analyticsRegion\":\"$AX_REGION\",
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
        \"hostnames\":[\"$ENV_GROUP_NAME.$DNS_NAME\"],
      }" \
      "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/envgroups"

    echo -n "⏳ Waiting for Apigeectl Env Creation "
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

    ENV_GROUP_NAME="$1"

    if [ -z "$(gcloud compute addresses list --format json --filter 'name=apigee-ingress-ip' --format='get(address)')" ]; then
      if [[ "$INGRESS_TYPE" == "external" ]]; then
        gcloud compute addresses create apigee-ingress-ip --region "$REGION"
      else
        gcloud compute addresses create apigee-ingress-ip --region "$REGION" --subnet default --purpose SHARED_LOADBALANCER_VIP
      fi
    fi
    INGRESS_IP=$(gcloud compute addresses list --format json --filter "name=apigee-ingress-ip" --format="get(address)")
    export INGRESS_IP

    if [ -z "$(gcloud dns managed-zones list --filter 'name=apigee-dns-zone' --format='get(name)')" ]; then
      if [[ "$INGRESS_TYPE" == "external" ]]; then
        gcloud dns managed-zones create apigee-dns-zone --dns-name="$DNS_NAME" --description=apigee-dns-zone
      else
        gcloud dns managed-zones create apigee-dns-zone --dns-name="$DNS_NAME" --description=apigee-dns-zone --visibility="private" --networks="default"
      fi

      rm -f transaction.yaml
      gcloud dns record-sets transaction start --zone=apigee-dns-zone
      gcloud dns record-sets transaction add "$INGRESS_IP" \
          --name="$ENV_GROUP_NAME.$DNS_NAME." --ttl=600 \
          --type=A --zone=apigee-dns-zone
      gcloud dns record-sets transaction describe --zone=apigee-dns-zone
      gcloud dns record-sets transaction execute --zone=apigee-dns-zone
    fi

    if [[ "$INGRESS_TYPE" == "external" ]]; then
      NAME_SERVER=$(gcloud dns managed-zones describe apigee-dns-zone --format="json" --format="get(nameServers[0])")
      export NAME_SERVER
      echo "👋 Add this as an NS record for $DNS_NAME: $NAME_SERVER"
    fi

    echo "✅ Networking set up"
}

create_gke_cluster() {
    echo "🚀 Create GKE cluster"

    if [ -z "$(gcloud container clusters list --filter "name=$GKE_CLUSTER_NAME" --format='get(name)')" ]; then
      gcloud container clusters create "$GKE_CLUSTER_NAME" \
        --zone "$ZONE" \
        --network default \
        --subnetwork default \
        --default-max-pods-per-node "110" \
        --enable-ip-alias \
        --machine-type "$GKE_CLUSTER_MACHINE_TYPE" \
        --num-nodes "3" \
        --enable-autoscaling --min-nodes "3" --max-nodes "6" \
        --labels mesh_id="$MESH_ID" \
        --workload-pool "$WORKLOAD_POOL" \
        --enable-stackdriver-kubernetes
    fi

    gcloud container clusters get-credentials $GKE_CLUSTER_NAME --zone $ZONE

    kubectl create clusterrolebinding cluster-admin-binding \
      --clusterrole cluster-admin --user "$(gcloud config get-value account)" || true

    echo "✅ GKE set up"
}


install_asm_and_certmanager() {

  echo "👩🏽‍💼 Creating Cert Manager"
  kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/$CERT_MANAGER_VERSION/cert-manager.yaml

  echo "🏗️ Installing Anthos Service Mesh"
  mkdir -p "$QUICKSTART_TOOLS"/istio-asm
  curl https://storage.googleapis.com/csm-artifacts/asm/install_asm_1.7 > "$QUICKSTART_TOOLS"/istio-asm/install_asm
  chmod +x "$QUICKSTART_TOOLS"/istio-asm/install_asm

  mkdir -p "$QUICKSTART_TOOLS"/kpt
  curl -L -o "$QUICKSTART_TOOLS/kpt/kpt.tar.gz" "https://github.com/GoogleContainerTools/kpt/releases/download/${KPT_VERSION}/${KPT_BINARY}"
  tar xzf "$QUICKSTART_TOOLS/kpt/kpt.tar.gz" -C "$QUICKSTART_TOOLS/kpt"
  export PATH=$PATH:"$QUICKSTART_TOOLS"/kpt

  mkdir -p "$QUICKSTART_TOOLS"/jq
  curl -L -o "$QUICKSTART_TOOLS"/jq/jq "https://github.com/stedolan/jq/releases/download/$JQ_VERSION"
  chmod +x "$QUICKSTART_TOOLS"/jq/jq
  export PATH="$QUICKSTART_TOOLS"/jq:$PATH

  "$QUICKSTART_TOOLS"/istio-asm/install_asm \
    --project_id "$PROJECT_ID" \
    --cluster_name "$GKE_CLUSTER_NAME" \
    --cluster_location "$ZONE" \
    --mode install \
    --output_dir "$QUICKSTART_TOOLS"/istio-asm \
    --only_validate

  mv "$QUICKSTART_TOOLS"/istio-asm/istio-*/* "$QUICKSTART_TOOLS/istio-asm/." || echo "[WARN] cannot move directory. Exists already?"

  echo "🩹 Patching the ASM Config"
  mkdir -p "$QUICKSTART_TOOLS"/kpt
  curl -L -o "$QUICKSTART_TOOLS/kpt/kpt.tar.gz" "https://github.com/GoogleContainerTools/kpt/releases/download/${KPT_VERSION}/${KPT_BINARY}"
  tar xzf "$QUICKSTART_TOOLS/kpt/kpt.tar.gz" -C "$QUICKSTART_TOOLS/kpt"

  "$QUICKSTART_TOOLS"/kpt/kpt cfg set "$QUICKSTART_TOOLS"/istio-asm/asm gcloud.container.cluster "$GKE_CLUSTER_NAME"
  "$QUICKSTART_TOOLS"/kpt/kpt cfg set "$QUICKSTART_TOOLS"/istio-asm/asm gcloud.core.project "$PROJECT_ID"
  "$QUICKSTART_TOOLS"/kpt/kpt cfg set "$QUICKSTART_TOOLS"/istio-asm/asm gcloud.compute.location "$ZONE"
  "$QUICKSTART_TOOLS"/kpt/kpt cfg set "$QUICKSTART_TOOLS"/istio-asm/asm gcloud.project.environProjectNumber "$MESH_ID"
  "$QUICKSTART_TOOLS"/kpt/kpt cfg set "$QUICKSTART_TOOLS"/istio-asm/asm anthos.servicemesh.rev asm-173-6

  "$QUICKSTART_TOOLS"/istio-asm/bin/istioctl install -f "$QUICKSTART_TOOLS"/istio-asm/asm/istio/istio-operator.yaml \
    --revision=asm-173-6 \
    --set values.gateways.istio-ingressgateway.loadBalancerIP="$INGRESS_IP" \
    --set values.gateways.istio-ingressgateway.serviceAnnotations.'networking\.gke\.io/load-balancer-type'=$INGRESS_TYPE \
    --set meshConfig.enableAutoMtls=false \
    --set meshConfig.accessLogFile=/dev/stdout \
    --set meshConfig.accessLogEncoding=1 \
    --set meshConfig.accessLogFormat='{"start_time":"%START_TIME%","remote_address":"%DOWNSTREAM_DIRECT_REMOTE_ADDRESS%","user_agent":"%REQ(USER-AGENT)%","host":"%REQ(:AUTHORITY)%","request":"%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%","request_time":"%DURATION%","status":"%RESPONSE_CODE%","status_details":"%RESPONSE_CODE_DETAILS%","bytes_received":"%BYTES_RECEIVED%","bytes_sent":"%BYTES_SENT%","upstream_address":"%UPSTREAM_HOST%","upstream_response_flags":"%RESPONSE_FLAGS%","upstream_response_time":"%RESPONSE_DURATION%","upstream_service_time":"%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%","upstream_cluster":"%UPSTREAM_CLUSTER%","x_forwarded_for":"%REQ(X-FORWARDED-FOR)%","request_method":"%REQ(:METHOD)%","request_path":"%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%","request_protocol":"%PROTOCOL%","tls_protocol":"%DOWNSTREAM_TLS_VERSION%","request_id":"%REQ(X-REQUEST-ID)%","sni_host":"%REQUESTED_SERVER_NAME%","apigee_dynamic_data":"%DYNAMIC_METADATA(envoy.lua)%"}'

  echo "✅ ASM installed"
}

download_apigee_ctl() {
    echo "📥 Setup Apigeectl"

    APIGEECTL_ROOT="$QUICKSTART_TOOLS/apigeectl"

    # Remove if it existed from an old install
    if [ -d "$APIGEECTL_ROOT" ]; then rm -rf "$APIGEECTL_ROOT"; fi
    mkdir -p "$APIGEECTL_ROOT"

    curl -L \
      -o "$APIGEECTL_ROOT/apigeectl.tar.gz" \
      "https://storage.googleapis.com/apigee-release/hybrid/apigee-hybrid-setup/$APIGEE_CTL_VERSION/$APIGEE_CTL"

    tar xvzf "$APIGEECTL_ROOT/apigeectl.tar.gz" -C "$APIGEECTL_ROOT"
    rm "$APIGEECTL_ROOT/apigeectl.tar.gz"

    mv "$APIGEECTL_ROOT"/apigeectl_*_64 "$APIGEECTL_HOME"
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

    echo "✅ Hybrid Config Setup"
}

create_self_signed_cert() {

  ENV_GROUP_NAME=$1

  echo "🙈 Creating self-signed cert - $ENV_GROUP_NAME"
  mkdir  -p "$HYBRID_HOME/certs"

  CA_CERT_NAME="quickstart-ca"

  # create CA cert if not exist
  if [ -f "$HYBRID_HOME/certs/$CA_CERT_NAME.crt" ]; then
    echo "CA already exists! Reusing that one."
  else
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj "/CN=$DNS_NAME/O=Apigee Quickstart" -keyout "$HYBRID_HOME/certs/$CA_CERT_NAME.key" -out "$HYBRID_HOME/certs/$CA_CERT_NAME.crt"
  fi

  openssl req -out "$HYBRID_HOME/certs/$ENV_GROUP_NAME.csr" -newkey rsa:2048 -nodes -keyout "$HYBRID_HOME/certs/$ENV_GROUP_NAME.key" -subj "/CN=$ENV_GROUP_NAME.$DNS_NAME/O=Apigee Quickstart"

  openssl x509 -req -days 365 -CA "$HYBRID_HOME/certs/$CA_CERT_NAME.crt" -CAkey "$HYBRID_HOME/certs/$CA_CERT_NAME.key" -set_serial 0 -in "$HYBRID_HOME/certs/$ENV_GROUP_NAME.csr" -out "$HYBRID_HOME/certs/$ENV_GROUP_NAME.crt"

  cat "$HYBRID_HOME/certs/$ENV_GROUP_NAME.crt" "$HYBRID_HOME/certs/$CA_CERT_NAME.crt" > "$HYBRID_HOME/certs/$ENV_GROUP_NAME.fullchain.crt"
}

create_sa() {
    for SA in mart cassandra udca metrics synchronizer logger watcher distributed-trace
    do
      yes | "$APIGEECTL_HOME"/tools/create-service-account "apigee-$SA" "$HYBRID_HOME/service-accounts"
    done
}

install_runtime() {
  ENV_NAME=$1
  ENV_GROUP_NAME=$2
  echo "Configure Overrides"

  cat << EOF > "$HYBRID_HOME"/overrides/overrides.yaml
gcp:
  projectID: $PROJECT_ID
  region: "$REGION" # Analytics Region
# Apigee org name.
org: $PROJECT_ID
# Kubernetes cluster name details
k8sCluster:
  name: $GKE_CLUSTER_NAME
  region: "$REGION"

virtualhosts:
  - name: $ENV_GROUP_NAME
    sslCertPath: $HYBRID_HOME/certs/$ENV_GROUP_NAME.fullchain.crt
    sslKeyPath: $HYBRID_HOME/certs/$ENV_GROUP_NAME.key

instanceID: "$PROJECT_ID-$(date +%s)"

envs:
  - name: $ENV_NAME
    serviceAccountPaths:
      synchronizer: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-synchronizer.json"
      udca: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-udca.json"
      runtime: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-distributed-trace.json"
mart:
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-mart.json"

connectAgent:
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-mart.json"

metrics:
  enabled: true
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-metrics.json"

watcher:
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-watcher.json"

logger:
  enabled: false
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-logger.json"

EOF
    pushd "$HYBRID_HOME" || return # because apigeectl uses pwd-relative paths
    mkdir -p "$HYBRID_HOME"/generated
    "$APIGEECTL_HOME"/apigeectl init -f "$HYBRID_HOME"/overrides/overrides.yaml --print-yaml > "$HYBRID_HOME"/generated/apigee-init.yaml
    echo -n "⏳ Waiting for Apigeectl init "
    wait_for_ready "0" "$APIGEECTL_HOME/apigeectl check-ready -f $HYBRID_HOME/overrides/overrides.yaml > /dev/null  2>&1; echo \$?" "apigeectl init: done."

    "$APIGEECTL_HOME"/apigeectl apply -f "$HYBRID_HOME"/overrides/overrides.yaml --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml

    echo -n "⏳ Waiting for Apigeectl apply "
    wait_for_ready "0" "$APIGEECTL_HOME/apigeectl check-ready -f $HYBRID_HOME/overrides/overrides.yaml > /dev/null  2>&1; echo \$?" "apigeectl apply: done."

    popd || return

    echo -n "🔛 Enabling runtime synchronizer"
    curl -X POST -H "Authorization: Bearer $(token)" \
    -H "Content-Type:application/json" \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}:setSyncAuthorization" \
    -d "{\"identities\":[\"serviceAccount:apigee-synchronizer@${PROJECT_ID}.iam.gserviceaccount.com\"]}"

    echo -n "🕵️‍♀️ Turn on trace logs"
    curl -X POST -H "Authorization: Bearer $(token)" \
    -H "Content-Type:application/json" \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}/environments/$ENV_NAME/traceConfig" \
    -d "{\"exporter\":\"CLOUD_TRACE\",\"endpoint\":\"${PROJECT_ID}\",\"sampling_config\":{\"sampler\":\"PROBABILITY\",\"sampling_rate\":0.5}}"

    echo "🎉🎉🎉 Hybrid installation completed!"
}

deploy_example_proxy() {
  echo "🦄 Deploy Sample Proxy"

  ENV_NAME=$1
  ENV_GROUP_NAME=$2

  (cd "$QUICKSTART_ROOT/example-proxy" && zip -r apiproxy.zip apiproxy/*)

  PROXY_REV=$(curl -X POST \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}/apis?action=import&name=httpbin-v0&validate=true" \
    -H "Authorization: Bearer $(token)" \
    -H "Content-Type: multipart/form-data" \
    -F "zipFile=@$QUICKSTART_ROOT/example-proxy/apiproxy.zip" | grep '"revision": "[^"]*' | cut -d'"' -f4)

  rm "$QUICKSTART_ROOT/example-proxy/apiproxy.zip"

  curl -X POST \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}/environments/$ENV_NAME/apis/httpbin-v0/revisions/${PROXY_REV}/deployments?override=true" \
    -H "Authorization: Bearer $(token)" \
    -H "Content-Length: 0"

  echo "✅ Sample Proxy Deployed"

  echo "🤓 Try without DNS (first deployment takes a few seconds. Relax and breathe!):"
  echo "curl --cacert $QUICKSTART_ROOT/hybrid-files/certs/quickstart-ca.crt --resolve $ENV_GROUP_NAME.$DNS_NAME:443:$INGRESS_IP https://$ENV_GROUP_NAME.$DNS_NAME/httpbin/v0/anything"

  echo "👋 To reach it via the FQDN: Make sure you add this as an NS record for $DNS_NAME: $NAME_SERVER"
}

delete_apigee_keys() {
  for SA in mart cassandra udca metrics synchronizer logger watcher distributed-trace
  do
    delete_sa_keys "apigee-${SA}"
  done
}

delete_sa_keys() {
  SA=$1
  for SA_KEY_NAME in $(gcloud iam service-accounts keys list --iam-account="${SA}@${PROJECT_ID}.iam.gserviceaccount.com" --format="get(name)")
  do
    gcloud iam service-accounts keys delete "$SA_KEY_NAME" --iam-account="$SA@$PROJECT_ID.iam.gserviceaccount.com" --filter="keyType=USER_MANAGED" -q
  done
}
