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
    PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value "project")}
    export PROJECT_ID
    gcloud config set project "$PROJECT_ID"

    export AX_REGION=${AX_REGION:-'europe-west1'}

    export REGION=${REGION:-'europe-west1'}
    gcloud config set compute/region "$REGION"

    export ZONE=${ZONE:-'europe-west1-c'}
    gcloud config set compute/zone "$ZONE"

    printf "\n🔧 Apigee hybrid Configuration:\n"
    export INGRESS_TYPE=${INGRESS_TYPE:-'external'} # internal|external
    echo "- Ingress type $INGRESS_TYPE"
    export CERT_TYPE=${CERT_TYPE:-google-managed}
    echo "- TLS Certificate $CERT_TYPE"

    export GKE_CLUSTER_NAME=${GKE_CLUSTER_NAME:-apigee-hybrid}
    export GKE_CLUSTER_MACHINE_TYPE=${GKE_CLUSTER_MACHINE_TYPE:-e2-standard-4}
    echo "- GKE Node Type $GKE_CLUSTER_MACHINE_TYPE"
    export APIGEE_CTL_VERSION='1.6.3'
    echo "- Apigeectl version $APIGEE_CTL_VERSION"
    export KPT_VERSION='v0.34.0'
    echo "- kpt version $KPT_VERSION"
    export CERT_MANAGER_VERSION='v1.2.0'
    echo "- Cert Manager version $CERT_MANAGER_VERSION"
    export ASM_VERSION='1.9'
    echo "- ASM version $ASM_VERSION"

    OS_NAME=$(uname -s)

    if [[ "$OS_NAME" == "Linux" ]]; then
      echo "- 🐧 Using Linux binaries"
      export APIGEE_CTL='apigeectl_linux_64.tar.gz'
      export KPT_BINARY='kpt_linux_amd64-0.34.0.tar.gz'
      export JQ_VERSION='jq-1.6/jq-linux64'
    elif [[ "$OS_NAME" == "Darwin" ]]; then
      echo "- 🍏 Using macOS binaries"
      export APIGEE_CTL='apigeectl_mac_64.tar.gz'
      export KPT_BINARY='kpt_darwin_amd64-0.34.0.tar.gz'
      export JQ_VERSION='jq-1.6/jq-osx-amd64'
    else
      echo "💣 Only Linux and macOS are supported at this time. You seem to be running on $OS_NAME."
      exit 2
    fi


    printf "\n🔧 Derived config parameters\n"
    echo "- GCP Project $PROJECT_ID"
    PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
    export PROJECT_NUMBER
    export WORKLOAD_POOL="${PROJECT_ID}.svc.id.goog"
    echo "- Workload Pool $WORKLOAD_POOL"
    export MESH_ID="proj-${PROJECT_NUMBER}"
    echo "- Mesh ID $MESH_ID"

    # these will be set if the steps are run in order
    INGRESS_IP=$(gcloud compute addresses list --format json --filter "name=apigee-ingress-ip" --regions="$REGION" --format="get(address)" || echo "")
    export INGRESS_IP
    echo "- Ingress IP ${INGRESS_IP:-N/A}"
    NAME_SERVER=$(gcloud dns managed-zones describe apigee-dns-zone --format="json" --format="get(nameServers[0])" 2>/dev/null || echo "")
    export NAME_SERVER
    echo "- Nameserver ${NAME_SERVER:-N/A}"

    export QUICKSTART_ROOT="${QUICKSTART_ROOT:-$PWD}"
    export QUICKSTART_TOOLS="$QUICKSTART_ROOT/tools"
    export APIGEECTL_HOME=$QUICKSTART_TOOLS/apigeectl/apigeectl_$APIGEE_CTL_VERSION
    export HYBRID_HOME=$QUICKSTART_ROOT/hybrid-files

    echo "- Script root from: $QUICKSTART_ROOT"
}

token() { echo -n "$(gcloud config config-helper --force-auth-refresh | grep access_token | grep -o -E '[^ ]+$')" ; }

function wait_for_ready(){
    local expected_output=$1
    local action=$2
    local message=$3
    local max_iterations=120 # 10min
    local iterations=0
    local actual_out

    echo -e "Waiting for $action to return output $expected_output"
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

ask_confirm() {
  if [ ! "$QUIET_INSTALL" = "true" ]; then
    printf "\n\n"
    read -p "Do you want to continue with the config above? [Y/n]: " -n 1 -r REPLY; printf "\n"
    REPLY=${REPLY:-Y}

    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      echo "starting provisioning"
    else
      exit 1
    fi
  fi
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

  PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value "project")}

  echo "📝 Enabling all required APIs in GCP project \"$PROJECT_ID\""
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
      return 0
    fi

    curl -X POST --fail -H "Authorization: Bearer $(token)" -H "content-type:application/json" \
    -d "{
        \"name\":\"$PROJECT_ID\",
        \"displayName\":\"$PROJECT_ID\",
        \"description\":\"Apigee hybrid Org\",
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

    curl -X POST --fail -H "Authorization: Bearer $(token)" -H "content-type:application/json" \
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

    curl -X POST --fail -H "Authorization: Bearer $(token)" -H "content-type:application/json" \
      -d "{
        \"name\":\"$ENV_GROUP_NAME\",
        \"hostnames\":[\"$ENV_GROUP_NAME.${DNS_NAME:-$PROJECT_ID.apigee.com}\"],
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

  if curl --fail --silent -H "Authorization: Bearer $(token)" -H "content-type:application/json" "$ENV_GROUPS_ATTACHMENT_URI" | grep -q "\"environment\": \"$ENV_NAME\""; then
    echo "(skipping, envgroup assignment already exists)"
    return
  else
    curl -X POST --fail -q -H "Authorization: Bearer $(token)"  -H "content-type:application/json" \
      -d '{ "environment": "'"$ENV_NAME"'" }' "$ENV_GROUPS_ATTACHMENT_URI"
  fi

  echo "✅ Added Env $ENV_NAME to Env Group $ENV_GROUP_NAME"
}

configure_network() {
    echo "🌐 Setup Networking"

    ENV_GROUP_NAME="$1"

    if [ -z "$(gcloud compute addresses list --format json --filter 'name=apigee-ingress-ip' --regions=$REGION --format='get(address)')" ]; then
      if [[ "$INGRESS_TYPE" == "external" && "$CERT_TYPE" == "google-managed" ]]; then
        gcloud compute addresses create apigee-ingress-ip --global
      elif [[ "$INGRESS_TYPE" == "external" && "$CERT_TYPE" == "self-signed" ]]; then
        gcloud compute addresses create apigee-ingress-ip --region "$REGION"
      else
        gcloud compute addresses create apigee-ingress-ip --region "$REGION" --subnet default --purpose SHARED_LOADBALANCER_VIP
      fi
    fi
    INGRESS_IP=$(gcloud compute addresses list --format json --filter "name=apigee-ingress-ip" --regions=$REGION --format="get(address)")
    export INGRESS_IP

    export DNS_NAME=${DNS_NAME:="$(echo "$INGRESS_IP" | tr '.' '-').nip.io"}

    echo "setting hostname on env group to $ENV_GROUP_NAME.$DNS_NAME"
    curl -X PATCH --silent -H "Authorization: Bearer $(token)"  \
      -H "Content-Type:application/json" https://apigee.googleapis.com/v1/organizations/"$PROJECT_ID"/envgroups/"$ENV_GROUP_NAME" \
      -d "{\"hostnames\": [\"$ENV_GROUP_NAME.$DNS_NAME\"]}"

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
        --region "$REGION" \
        --node-locations "$ZONE" \
        --release-channel stable \
        --network default \
        --subnetwork default \
        --default-max-pods-per-node "110" \
        --enable-ip-alias \
        --machine-type "$GKE_CLUSTER_MACHINE_TYPE" \
        --num-nodes "3" \
        --enable-autoscaling \
        --min-nodes "3" \
        --max-nodes "6" \
        --labels mesh_id="$MESH_ID" \
        --workload-pool "$WORKLOAD_POOL" \
        --logging SYSTEM,WORKLOAD \
        --monitoring SYSTEM
    fi

    gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" --region "$REGION"

    kubectl create clusterrolebinding cluster-admin-binding \
      --clusterrole cluster-admin --user "$(gcloud config get-value account)" || true

    echo "✅ GKE set up"
}


install_certmanager() {
  echo "👩🏽‍💼 Creating Cert Manager"
  kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/$CERT_MANAGER_VERSION/cert-manager.yaml
}

install_asm() {
  echo "🏗️ Preparing ASM install requirements"
  mkdir -p "$QUICKSTART_TOOLS"/kpt
  curl --fail -L -o "$QUICKSTART_TOOLS/kpt/kpt.tar.gz" "https://github.com/GoogleContainerTools/kpt/releases/download/${KPT_VERSION}/${KPT_BINARY}"
  tar xzf "$QUICKSTART_TOOLS/kpt/kpt.tar.gz" -C "$QUICKSTART_TOOLS/kpt"
  export PATH=$PATH:"$QUICKSTART_TOOLS"/kpt

  mkdir -p "$QUICKSTART_TOOLS"/jq
  curl --fail -L -o "$QUICKSTART_TOOLS"/jq/jq "https://github.com/stedolan/jq/releases/download/$JQ_VERSION"
  chmod +x "$QUICKSTART_TOOLS"/jq/jq
  export PATH=$PATH:"$QUICKSTART_TOOLS"/jq

  echo "🏗️ Installing Anthos Service Mesh"
  mkdir -p "$QUICKSTART_TOOLS"/istio-asm
  curl --fail https://storage.googleapis.com/csm-artifacts/asm/install_asm_$ASM_VERSION > "$QUICKSTART_TOOLS"/istio-asm/install_asm
  chmod +x "$QUICKSTART_TOOLS"/istio-asm/install_asm

  # patch ASM installer to allow for cloud build SA
  sed -i -e 's/iam.gserviceaccount.com/gserviceaccount.com/g' "$QUICKSTART_TOOLS"/istio-asm/install_asm

  # patch ASM installer to use the new kubectl --dry-run syntax
  sed -i -e 's/--dry-run/--dry-run=client/g' "$QUICKSTART_TOOLS"/istio-asm/install_asm

  if [ "$CERT_TYPE" = "google-managed" ];then
    cat << EOF > "$QUICKSTART_TOOLS"/istio-asm/istio-operator-patch.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  components:
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        serviceAnnotations:
          cloud.google.com/neg: '{"ingress": true}'
          cloud.google.com/backend-config: '{"default": "ingress-backendconfig"}'
          cloud.google.com/app-protocols: '{"https":"HTTPS"}'
        service:
          type: ClusterIP
          ports:
          - name: status-port
            port: 15021 # for ASM 1.7.x and above, else 15020
            targetPort: 15021 # for ASM 1.7.x and above, else 15020
          - name: https
            port: 443
            targetPort: 8443
EOF
  else
    cat << EOF > "$QUICKSTART_TOOLS"/istio-asm/istio-operator-patch.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  components:
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        serviceAnnotations:
          networking.gke.io/load-balancer-type: $INGRESS_TYPE
        service:
          type: LoadBalancer
          loadBalancerIP: $INGRESS_IP
          ports:
          - name: status-port
            port: 15021 # for ASM 1.7.x and above, else 15020
            targetPort: 15021 # for ASM 1.7.x and above, else 15020
          - name: https
            port: 443
            targetPort: 8443
EOF
  fi

  rm -rf "$QUICKSTART_TOOLS"/istio-asm/install-out
  mkdir -p "$QUICKSTART_TOOLS"/istio-asm/install-out
  ln -s "$QUICKSTART_TOOLS/kpt/kpt"  "$QUICKSTART_TOOLS"/istio-asm/install-out/kpt

  "$QUICKSTART_TOOLS"/istio-asm/install_asm \
    --project_id "$PROJECT_ID" \
    --cluster_name "$GKE_CLUSTER_NAME" \
    --cluster_location "$REGION" \
    --output_dir "$QUICKSTART_TOOLS"/istio-asm/install-out \
    --custom_overlay "$QUICKSTART_TOOLS"/istio-asm/istio-operator-patch.yaml \
    --enable_all \
    --mode install

  echo "✅ ASM installed"
}

download_apigee_ctl() {
    echo "📥 Setup Apigeectl"

    APIGEECTL_ROOT="$QUICKSTART_TOOLS/apigeectl"

    # Remove if it existed from an old install
    if [ -d "$APIGEECTL_ROOT" ]; then rm -rf "$APIGEECTL_ROOT"; fi
    mkdir -p "$APIGEECTL_ROOT"

    curl --fail -L \
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

create_cert() {

  ENV_GROUP_NAME=$1

  if [ "$CERT_TYPE" = "skip" ];then
    return
  fi

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

  kubectl create secret tls tls-hybrid-ingress \
    --cert="$HYBRID_HOME/certs/$ENV_GROUP_NAME.fullchain.crt" \
    --key="$HYBRID_HOME/certs/$ENV_GROUP_NAME.key" \
    -n istio-system --dry-run=client -o yaml | kubectl apply -f -

  if [ "$CERT_TYPE" = "google-managed" ];then
    echo "🏢 Letting Google manage the cert - $ENV_GROUP_NAME"

     cat <<EOF | kubectl apply -f -
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: apigee-xlb-cert
  namespace: istio-system
spec:
  domains:
    - "$ENV_GROUP_NAME.$DNS_NAME"
---
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: ingress-backendconfig
  namespace: istio-system
spec:
  healthCheck:
    requestPath: /healthz/ready
    port: 15021
    type: HTTP
  logging:
    enable: false
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    networking.gke.io/managed-certificates: "apigee-xlb-cert"
    kubernetes.io/ingress.global-static-ip-name: apigee-ingress-ip
    kubernetes.io/ingress.allow-http: "false"
  name: xlb-apigee-ingress
  namespace: istio-system
spec:
  defaultBackend:
    service:
      name: istio-ingressgateway
      port:
        number: 443
---
apiVersion: v1
kind: Namespace
metadata:
  name: apigee
---
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: apigee-wildcard
  namespace: apigee
spec:
  selector:
    app: istio-ingressgateway
  servers:
  - hosts:
    - '*'
    port:
      name: https-apigee-443
      number: 443
      protocol: HTTPS
    tls:
      credentialName: tls-hybrid-ingress
      mode: SIMPLE
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: health
  namespace: apigee
spec:
  gateways:
  - apigee-wildcard
  hosts:
  - '*'
  http:
  - match:
    - headers:
        user-agent:
          prefix: GoogleHC
      method:
        exact: GET
      uri:
        exact: /
    rewrite:
      authority: istio-ingressgateway.istio-system.svc.cluster.local:15021
      uri: /healthz/ready
    route:
    - destination:
        host: istio-ingressgateway.istio-system.svc.cluster.local
        port:
          number: 15021 # for ASM 1.7.x and above, else 15020
EOF

  fi
}

create_sa() {
  yes | "$APIGEECTL_HOME"/tools/create-service-account -e prod -d "$HYBRID_HOME/service-accounts"

  echo -n "🔛 Enabling runtime synchronizer"
    curl --fail -X POST -H "Authorization: Bearer $(token)" \
    -H "Content-Type:application/json" \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}:setSyncAuthorization" \
    -d "{\"identities\":[\"serviceAccount:apigee-synchronizer@${PROJECT_ID}.iam.gserviceaccount.com\"]}"
}

configure_runtime() {
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
    sslSecret: tls-hybrid-ingress
    additionalGateways: ["apigee-wildcard"]

instanceID: "$PROJECT_ID-$(date +%s)"

envs:
  - name: $ENV_NAME
    serviceAccountPaths:
      synchronizer: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-synchronizer.json"
      udca: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-udca.json"
      runtime: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-runtime.json"
mart:
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-mart.json"

connectAgent:
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-mart.json"

udca:
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-udca.json"

metrics:
  enabled: true
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-metrics.json"

watcher:
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-watcher.json"

logger:
  enabled: false
  serviceAccountPath: "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-logger.json"
EOF
}

install_runtime() {
    pushd "$HYBRID_HOME" || return # because apigeectl uses pwd-relative paths
    mkdir -p "$HYBRID_HOME"/generated
    "$APIGEECTL_HOME"/apigeectl init -f "$HYBRID_HOME"/overrides/overrides.yaml --print-yaml > "$HYBRID_HOME"/generated/apigee-init.yaml || ( sleep 120 && "$APIGEECTL_HOME"/apigeectl init -f "$HYBRID_HOME"/overrides/overrides.yaml --print-yaml > "$HYBRID_HOME"/generated/apigee-init.yaml )
    sleep 2 && echo -n "⏳ Waiting for Apigeectl init "
    wait_for_ready "Running" "kubectl get po -l app=apigee-controller -n apigee-system -o=jsonpath='{.items[0].status.phase}' 2>/dev/null" "Apigee Controller: Running"
    echo "waiting for 30s for the webhook certs to propagate" && sleep 30


    "$APIGEECTL_HOME"/apigeectl apply -f "$HYBRID_HOME"/overrides/overrides.yaml --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml || ( sleep 120 && "$APIGEECTL_HOME"/apigeectl apply -f "$HYBRID_HOME"/overrides/overrides.yaml --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml )
    sleep 2 && echo -n "⏳ Waiting for Apigeectl apply "
    wait_for_ready "Running" "kubectl get po -l app=apigee-runtime -n apigee -o=jsonpath='{.items[0].status.phase}' 2>/dev/null" "Apigee Runtime: Running."

    popd || return

    echo "🎉🎉🎉 Hybrid installation completed!"
}

enable_trace() {
  ENV_NAME=$1
  echo -n "🕵️‍♀️ Turn on trace logs"

    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member "serviceAccount:apigee-runtime@${PROJECT_ID}.iam.gserviceaccount.com" \
      --role=roles/cloudtrace.agent --project "$PROJECT_ID"

    curl --fail -X PATCH -H "Authorization: Bearer $(token)" \
    -H "Content-Type:application/json" \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}/environments/$ENV_NAME/traceConfig" \
    -d "{\"exporter\":\"CLOUD_TRACE\",\"endpoint\":\"${PROJECT_ID}\",\"sampling_config\":{\"sampler\":\"PROBABILITY\",\"sampling_rate\":0.5}}"
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

  if [ "$CERT_TYPE" = "self-signed" ];then
   echo "curl --cacert $QUICKSTART_ROOT/hybrid-files/certs/quickstart-ca.crt https://$ENV_GROUP_NAME.$DNS_NAME/httpbin/v0/anything"
  else
    echo "curl https://$ENV_GROUP_NAME.$DNS_NAME/httpbin/v0/anything"
  fi
  echo "👋 To reach your API via the FQDN: Make sure you add a DNS record for your FQDN or an NS record for $DNS_NAME: $NAME_SERVER"
  echo "👋 During development you can also use --resolve $ENV_GROUP_NAME.$DNS_NAME:443:$INGRESS_IP to resolve the hostname for your curl command"
}

delete_apigee_keys() {
  for SA in mart cassandra udca metrics synchronizer logger watcher distributed-trace runtime
  do
    delete_sa_keys "apigee-${SA}"
  done
}

delete_sa_keys() {
  SA=$1
  for SA_KEY_NAME in $(gcloud iam service-accounts keys list --iam-account="${SA}@${PROJECT_ID}.iam.gserviceaccount.com" --format="get(name)" --filter="keyType=USER_MANAGED")
  do
    gcloud iam service-accounts keys delete "$SA_KEY_NAME" --iam-account="$SA@$PROJECT_ID.iam.gserviceaccount.com" -q
  done
}
