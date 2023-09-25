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
    echo "- Project ID $PROJECT_ID"
    gcloud config set project "$PROJECT_ID"

    export AX_REGION=${AX_REGION:-'europe-west1'}
    echo "- Analytics Region $AX_REGION"

    export REGION=${REGION:-'europe-west1'}
    gcloud config set compute/region "$REGION"

    export ZONE=${ZONE:-'europe-west1-b,europe-west1-c,europe-west1-d'}
    echo "- Compute Location $REGION/$ZONE"

    export NETWORK=${NETWORK:-'apigee-hybrid'}
    export SUBNET=${SUBNET:-"apigee-$REGION"}
    export SUBNET_RANGE=${SUBNET_RANGE:-"10.200.0.0/20"}
    echo "- Network $NETWORK/$SUBNET - $SUBNET_RANGE"

    export PRIVATE_CLUSTER=${PRIVATE_CLUSTER:-'true'}
    echo "- Private Cluster $PRIVATE_CLUSTER"

    export CONTROL_PLANE_CIDR=${CONTROL_PLANE_CIDR:-'172.16.0.16/28'}
    echo "- GKE control plane CIDR (private cluster only) $CONTROL_PLANE_CIDR"


    printf "\n🔧 Apigee hybrid Configuration:\n"
    export ENV_NAME=${ENV_NAME:="test1"}
    echo "- Environment Name $ENV_NAME"
    export ENV_GROUP_NAME=${ENV_GROUP_NAME:="test"}
    echo "- Environment Group Name $ENV_GROUP_NAME"
    export INGRESS_IP_NAME=${INGRESS_IP_NAME:-'ingress-ip'} # internal|external
    echo "- Ingress address name $INGRESS_IP_NAME"
    export INGRESS_TYPE=${INGRESS_TYPE:-'external'} # internal|external
    echo "- Ingress type $INGRESS_TYPE"
    export CERT_TYPE=${CERT_TYPE:-google-managed}
    echo "- TLS Certificate $CERT_TYPE"

    if [ "$CERT_TYPE" == "google-managed" ] && [ "$INGRESS_TYPE" != "external" ]; then
        echo "Google Managed Certificates can only be used with an external ingress. SET CERT_TYPE to 'self-signed' (for the script to create one for you) or 'skip' if you want to provide your own as a k8s secret later."
        exit 1
    fi

    export GKE_CLUSTER_NAME=${GKE_CLUSTER_NAME:-apigee-hybrid}
    export GKE_CLUSTER_MACHINE_TYPE=${GKE_CLUSTER_MACHINE_TYPE:-e2-standard-4}
    echo "- GKE Node Type $GKE_CLUSTER_MACHINE_TYPE"
    export APIGEE_HYBRID_VERSION='1.10.0'
    echo "- Apigee hybrid version $APIGEE_HYBRID_VERSION"
    export CERT_MANAGER_VERSION='v1.12.2'
    echo "- Cert Manager version $CERT_MANAGER_VERSION"

    OS_NAME=$(uname -s)

    if [[ "$OS_NAME" == "Linux" ]]; then
      echo "- 🐧 Using Linux binaries"
      export APIGEE_CTL='apigeectl_linux_64.tar.gz'
    elif [[ "$OS_NAME" == "Darwin" ]]; then
      echo "- 🍏 Using macOS binaries"
      export APIGEE_CTL='apigeectl_mac_64.tar.gz'
      if ! [ -x "$(command -v timeout)" ]; then
        echo "Please install the timeout command for macOS. E.g. 'brew install coreutils'"
        exit 2
      fi
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

    INGRESS_IP=$(gcloud compute addresses list --format json --filter "name=$INGRESS_IP_NAME" --format="get(address)" || echo "")
    export INGRESS_IP
    echo "- Ingress IP ${INGRESS_IP:-N/A}"
    if [ -n "$INGRESS_IP" ]; then
      export DNS_NAME=${DNS_NAME:="$(echo "$INGRESS_IP" | tr '.' '-').nip.io"}
    fi
    echo "- DNS NAME ${DNS_NAME:-N/A}"
    NAME_SERVER=$(gcloud dns managed-zones describe apigee-dns-zone --format="json" --format="get(nameServers[0])" 2>/dev/null || echo "")
    export NAME_SERVER
    echo "- Nameserver ${NAME_SERVER:-N/A}"

    export QUICKSTART_ROOT="${QUICKSTART_ROOT:-$PWD}"
    export QUICKSTART_TOOLS="$QUICKSTART_ROOT/tools"
    export APIGEECTL_HOME=$QUICKSTART_TOOLS/apigeectl/apigeectl_$APIGEE_HYBRID_VERSION
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

    # shellcheck disable=SC2001
    sanitized="$(echo "$action" | sed 's/Bearer [^\"]*/TOKEN/gi')"
    echo -e "Waiting for $sanitized to return output $expected_output"
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
      echo "continuing"
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

    if [ -z "$(gcloud compute networks list --format json --filter "name=$NETWORK" --format='get(name)')" ]; then
      gcloud compute networks create "$NETWORK" --subnet-mode=custom
    fi

    if [ -z "$(gcloud compute networks subnets list --network "$NETWORK" --format json --filter "name=$SUBNET" --format='get(name)')" ]; then
      gcloud compute networks subnets create "$SUBNET" --network "$NETWORK" --range "$SUBNET_RANGE" --region "$REGION"
    fi

    if [ -z "$(gcloud compute routers list --format json --filter "name=rt-$REGION" --format='get(name)')" ]; then
      gcloud compute routers create "rt-$REGION" --network "$NETWORK"
    fi

    if [ -z "$(gcloud compute routers nats list --router "rt-$REGION" --format json --format='get(name)')" ]; then
      gcloud compute routers nats create "apigee-nat-$REGION" --router "rt-$REGION" --region "$REGION" --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges
    fi

    if [ -z "$(gcloud compute addresses list --format json --filter "name=$INGRESS_IP_NAME" --format='get(address)')" ]; then
      if [[ "$INGRESS_TYPE" == "external" && "$CERT_TYPE" == "google-managed" ]]; then
        gcloud compute addresses create "$INGRESS_IP_NAME" --global
      elif [[ "$INGRESS_TYPE" == "external" && "$CERT_TYPE" == "self-signed" ]]; then
        gcloud compute addresses create "$INGRESS_IP_NAME" --region "$REGION"
      else
        gcloud compute addresses create "$INGRESS_IP_NAME" --region "$REGION" --subnet "$SUBNET" --purpose SHARED_LOADBALANCER_VIP
      fi
    fi
    INGRESS_IP=$(gcloud compute addresses list --format json --filter "name=$INGRESS_IP_NAME" --format="get(address)")
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
        gcloud dns managed-zones create apigee-dns-zone --dns-name="$DNS_NAME" --description=apigee-dns-zone --visibility="private" --networks="$NETWORK"
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

      if [ "$PRIVATE_CLUSTER" = "true" ];then
        if [ -z "$(gcloud compute firewall-rules list --format json --filter "name=allow-master-$GKE_CLUSTER_NAME" --format='get(name)')" ]; then
          gcloud compute firewall-rules create "allow-master-$GKE_CLUSTER_NAME" --allow tcp:9443,tcp:15017 --target-tags hybrid-quickstart --network "$NETWORK" --source-ranges "$CONTROL_PLANE_CIDR"
        fi
        gcloud container clusters create "$GKE_CLUSTER_NAME" \
            --no-enable-master-authorized-networks \
            --enable-private-nodes \
            --master-ipv4-cidr="$CONTROL_PLANE_CIDR" \
            --tags="hybrid-quickstart,private-cluster" \
            --region "$REGION" \
            --node-locations "$ZONE" \
            --release-channel stable \
            --enable-ip-alias \
            --enable-shielded-nodes \
            --shielded-secure-boot \
            --shielded-integrity-monitoring \
            --network "$NETWORK" \
            --subnetwork "$SUBNET" \
            --default-max-pods-per-node "110" \
            --enable-ip-alias \
            --machine-type "$GKE_CLUSTER_MACHINE_TYPE" \
            --num-nodes "1" \
            --enable-autoscaling \
            --min-nodes "1" \
            --max-nodes "3" \
            --tags=hybrid-quickstart \
            --labels mesh_id="$MESH_ID" \
            --workload-pool "$WORKLOAD_POOL" \
            --logging SYSTEM,WORKLOAD \
            --monitoring SYSTEM
      else
        gcloud container clusters create "$GKE_CLUSTER_NAME" \
            --tags="hybrid-quickstart" \
            --region "$REGION" \
            --node-locations "$ZONE" \
            --release-channel stable \
            --enable-ip-alias \
            --enable-shielded-nodes \
            --shielded-secure-boot \
            --shielded-integrity-monitoring \
            --network "$NETWORK" \
            --subnetwork "$SUBNET" \
            --default-max-pods-per-node "110" \
            --enable-ip-alias \
            --machine-type "$GKE_CLUSTER_MACHINE_TYPE" \
            --num-nodes "1" \
            --enable-autoscaling \
            --min-nodes "1" \
            --max-nodes "3" \
            --tags=hybrid-quickstart \
            --labels mesh_id="$MESH_ID" \
            --workload-pool "$WORKLOAD_POOL" \
            --logging SYSTEM,WORKLOAD \
            --monitoring SYSTEM
      fi
    fi

    gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" --region "$REGION"

    kubectl create clusterrolebinding cluster-admin-binding \
      --clusterrole cluster-admin --user "$(gcloud config get-value account)" || true


    echo "✅ GKE set up"
}

install_certmanager() {
  echo "👩🏽‍💼 Creating Cert Manager"
  kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/$CERT_MANAGER_VERSION/cert-manager.yaml

  echo "Sleep for 2 minutes to ease API server pressure."
  sleep 120
}

download_apigee_ctl() {
    echo "📥 Setup Apigeectl"

    APIGEECTL_ROOT="$QUICKSTART_TOOLS/apigeectl"

    # Remove existing apigeectl
    if [ -d "$APIGEECTL_ROOT" ]; then rm -rf "$APIGEECTL_ROOT"; fi
    mkdir -p "$APIGEECTL_ROOT"

    curl --fail -L \
      -o "$APIGEECTL_ROOT/apigeectl.tar.gz" \
      "https://storage.googleapis.com/apigee-release/hybrid/apigee-hybrid-setup/$APIGEE_HYBRID_VERSION/$APIGEE_CTL"

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

  kubectl create ns apigee || echo "Couldn't create namespace Apigee. Does it already exist?"

  kubectl create secret tls tls-hybrid-ingress \
    --cert="$HYBRID_HOME/certs/$ENV_GROUP_NAME.fullchain.crt" \
    --key="$HYBRID_HOME/certs/$ENV_GROUP_NAME.key" \
    -n apigee --dry-run=client -o yaml | kubectl apply -f -

  if [ "$CERT_TYPE" = "google-managed" ];then
    echo "🏢 Letting Google manage the cert - $ENV_GROUP_NAME"

     cat <<EOF | kubectl apply -f -
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: "apigee-cert-$ENV_GROUP_NAME"
  namespace: apigee
spec:
  domains:
    - "$ENV_GROUP_NAME.$DNS_NAME"
---
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: ingress-backendconfig
  namespace: apigee
spec:
  healthCheck:
    requestPath: /healthz/ready
    port: 15021
    type: HTTP
  logging:
    enable: false
---
apiVersion: v1
kind: Service
metadata:
  name: apigee-ingressgateway-quickstart
  namespace: apigee
  annotations:
    cloud.google.com/backend-config: '{"default": "ingress-backendconfig"}'
    cloud.google.com/neg: '{"ingress": true}'
    cloud.google.com/app-protocols: '{"https":"HTTPS", "status-port": "HTTP"}'
  labels:
    app: apigee-ingressgateway-quickstart
spec:
  ports:
  - name: status-port
    port: 15021
    targetPort: 15021
  - name: https
    port: 443
    targetPort: 8443
  selector:
    app: apigee-ingressgateway
    ingress_name: apigee-ingress
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    networking.gke.io/managed-certificates: "apigee-cert-$ENV_GROUP_NAME"
    kubernetes.io/ingress.global-static-ip-name: $INGRESS_IP_NAME
    kubernetes.io/ingress.allow-http: "false"
  name: xlb-apigee-$ENV_GROUP_NAME
  namespace: apigee
spec:
  defaultBackend:
    service:
      name: apigee-ingressgateway-quickstart
      port:
        number: 443
EOF
  else
    kubectl create ns apigee
  fi
}

create_k8s_sa_workload() {
  K8S_SA=$1
  GCP_SA=$2
  kubectl create sa -n apigee "$K8S_SA" || echo "$K8S_SA exists"
  kubectl annotate sa --overwrite -n apigee "$K8S_SA" "iam.gke.io/gcp-service-account=$GCP_SA"

  gcloud iam service-accounts add-iam-policy-binding "$GCP_SA" \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:$PROJECT_ID.svc.id.goog[apigee/$K8S_SA]" --project "$PROJECT_ID"
}

create_sa() {

  # make sure we don't download the service account keys
  sed -i -e 's/download_key_file="y"/download_key_file="n"/g' "$APIGEECTL_HOME/tools/create-service-account"
  sed -i -e 's/read -r download_key_file/# key download is not necessary for workload ID/g' "$APIGEECTL_HOME/tools/create-service-account"

  yes | "$APIGEECTL_HOME"/tools/create-service-account -e prod -d "$HYBRID_HOME/service-accounts"

  APIGEE_ORG_HASH="$("$APIGEECTL_HOME"/apigeectl encode --org "$PROJECT_ID" 2>&1 | tail -1 | xargs | sed -e "s/^apigee-udca-//")"
  APIGEE_ORG_ENV_HASH="$("$APIGEECTL_HOME"/apigeectl encode --org "$PROJECT_ID" --env "$ENV_NAME" 2>&1 | tail -1 | xargs | sed -e "s/^apigee-udca-//")"

  create_k8s_sa_workload "apigee-cassandra-schema-setup-$APIGEE_ORG_HASH-sa" "apigee-cassandra@$PROJECT_ID.iam.gserviceaccount.com"
  create_k8s_sa_workload "apigee-cassandra-user-setup-$APIGEE_ORG_HASH-sa" "apigee-cassandra@$PROJECT_ID.iam.gserviceaccount.com"
  create_k8s_sa_workload "apigee-mart-$APIGEE_ORG_HASH-sa" "apigee-mart@$PROJECT_ID.iam.gserviceaccount.com"
  create_k8s_sa_workload "apigee-connect-agent-$APIGEE_ORG_HASH-sa" "apigee-mart@$PROJECT_ID.iam.gserviceaccount.com"
  create_k8s_sa_workload "apigee-watcher-$APIGEE_ORG_HASH-sa" "apigee-watcher@$PROJECT_ID.iam.gserviceaccount.com"
  create_k8s_sa_workload "apigee-runtime-$APIGEE_ORG_ENV_HASH-sa" "apigee-runtime@$PROJECT_ID.iam.gserviceaccount.com"
  create_k8s_sa_workload "apigee-udca-$APIGEE_ORG_HASH-sa" "apigee-udca@$PROJECT_ID.iam.gserviceaccount.com"
  create_k8s_sa_workload "apigee-udca-$APIGEE_ORG_ENV_HASH-sa" "apigee-udca@$PROJECT_ID.iam.gserviceaccount.com"
  create_k8s_sa_workload "apigee-synchronizer-$APIGEE_ORG_ENV_HASH-sa" "apigee-synchronizer@$PROJECT_ID.iam.gserviceaccount.com"
  create_k8s_sa_workload "apigee-metrics-apigee-telemetry" "apigee-metrics@$PROJECT_ID.iam.gserviceaccount.com"
  create_k8s_sa_workload "apigee-metrics-adapter-apigee-telemetry" "apigee-metrics@$PROJECT_ID.iam.gserviceaccount.com"

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
  region: "$AX_REGION" # Analytics Region
  workloadIdentityEnabled: true
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
    selector:
      app: apigee-ingressgateway

instanceID: "$GKE_CLUSTER_NAME-$REGION"

envs:
  - name: $ENV_NAME

logger:
  enabled: false

ao:
  args:
    disableIstioConfigInAPIServer: true

ingressGateways:
- name: apigee-ingress
  replicaCountMin: 2
  replicaCountMax: 4
EOF

if [ "$CERT_TYPE" = "google-managed" ]; then
  echo "Do not create a LB because the ingress resource is used to create a GCLB with a managed cert"
cat << EOF >> "$HYBRID_HOME"/overrides/overrides.yaml
  svcType: ClusterIP
EOF
else
cat << EOF >> "$HYBRID_HOME"/overrides/overrides.yaml
  svcAnnotations:
    networking.gke.io/load-balancer-type: "$INGRESS_TYPE"
  svcLoadBalancerIP: $INGRESS_IP
EOF
fi

}

apigeectl_init() {
  echo -n "🏃 Running apigeectl init"
  "$APIGEECTL_HOME"/apigeectl init -f "$HYBRID_HOME"/overrides/overrides.yaml --print-yaml > "$HYBRID_HOME"/generated/apigee-init.yaml
}

apigeectl_apply() {
  echo -n "🏃 Running apigeectl apply"
  timeout 300 bash -c 'until kubectl wait --for=condition=ready --timeout 60s pod -l app=apigee-controller -n apigee-system; do sleep 10; done'
  "$APIGEECTL_HOME"/apigeectl apply -f "$HYBRID_HOME"/overrides/overrides.yaml --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml
}

install_wildcard_gateway() {
  timeout 300 bash -c 'until kubectl wait --for=condition=ready --timeout 60s pod -l app=apigee-controller -n apigee-system; do sleep 10; done'
  kubectl apply -f "$HYBRID_HOME"/generated/wildcard-gateway.yaml
}


install_runtime() {
    pushd "$HYBRID_HOME" || return # because apigeectl uses pwd-relative paths
    mkdir -p "$HYBRID_HOME"/generated

    export -f apigeectl_init
    timeout 1200 bash -c 'until apigeectl_init; do sleep 30; done'

    echo -n "⏳ Waiting for Apigeectl init "
    timeout 600 bash -c 'until kubectl wait --for=condition=ready --timeout 60s pod -l app=apigee-controller -n apigee-system; do sleep 10; done'
    timeout 600 bash -c 'until kubectl wait --for=condition=ready --timeout 60s issuer apigee-selfsigned-issuer -n apigee-system; do sleep 10; done'
    timeout 600 bash -c 'until kubectl wait --for=condition=ready --timeout 60s certificate apigee-serving-cert -n apigee-system; do sleep 10; done'
    timeout 720 bash -c 'until kubectl wait --for=condition=complete --timeout 60s job/apigee-resources-install  -n apigee-system; do sleep 10; done'

    export -f apigeectl_apply
    timeout 720 bash -c 'until apigeectl_apply; do sleep 20; done'

    echo -n "⏳ Waiting for Apigeectl apply "
    timeout 1800 bash -c 'until kubectl wait --for=condition=ready --timeout 60s pod -l app=apigee-runtime -n apigee; do sleep 10; done'

    cat << EOF > "$HYBRID_HOME"/generated/wildcard-gateway.yaml
apiVersion: apigee.cloud.google.com/v1alpha1
kind: ApigeeRoute
metadata:
  name: apigee-wildcard
  namespace: apigee
spec:
  hostnames:
  - '*'
  ports:
  - number: 443
    protocol: HTTPS
    tls:
      credentialName: tls-hybrid-ingress
      mode: SIMPLE
  selector:
    app: apigee-ingressgateway
  enableNonSniClient: true
EOF

    export -f install_wildcard_gateway
    timeout 600 bash -c 'until install_wildcard_gateway; do sleep 20; done'

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

  kubectl apply -f "$QUICKSTART_ROOT/example-proxy/resources.yaml"

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
