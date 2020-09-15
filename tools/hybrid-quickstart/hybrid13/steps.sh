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
    export PROJECT_ID=${PROJECT_ID:=$(gcloud config get-value "project")}
    gcloud config set project "$PROJECT_ID"
    export REGION=${REGION:='europe-west1'}
    gcloud config set compute/region $REGION
    export ZONE=${ZONE:='europe-west1-b'}
    gcloud config set compute/zone $ZONE

    echo "🔧 Configuring Apigee hybrid"
    export DNS_NAME=${DNS_NAME:="$PROJECT_ID.example.com"}
    export CLUSTER_NAME=${CLUSTER_NAME:=apigee-hybrid}

    export APIGEE_CTL_VERSION='1.3.2'
    export KPT_VERSION='v0.33.0'

    OS_NAME=$(uname -s)
    if [[ "$OS_NAME" == "Linux" ]]; then
      echo "🐧 Using Linux binaries"
      export APIGEE_CTL='apigeectl_linux_64.tar.gz'
      export ISTIO_ASM_CLI='istio-1.5.9-asm.0-linux.tar.gz'
      export KPT_BINARY='kpt_linux_amd64_0.33.0.tar.gz'
    elif [[ "$OS_NAME" == "Darwin" ]]; then
      echo "🍏 Using macOS binaries"
      export APIGEE_CTL='apigeectl_mac_64.tar.gz'
      export ISTIO_ASM_CLI='istio-1.5.9-asm.0-osx.tar.gz'
      export KPT_BINARY='kpt_darwin_amd64_0.33.0.tar.gz'
    else
      echo "💣 Only Linux and macOS are supported at this time. You seem to be running on $OS_NAME."
      exit 2
    fi

    echo "🔧 Setting derived config parameters"
    export PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
    export WORKLOAD_POOL=${PROJECT_ID}.svc.id.goog
    export MESH_ID="proj-${PROJECT_NUMBER}"

    # these will be set if the steps are run in order
    export INGRESS_IP=$(gcloud compute addresses list --format json --filter "name=apigee-ingress-loadbalancer" --format="get(address)")
    export NAME_SERVER=$(gcloud dns managed-zones describe apigee-dns-zone --format="json" --format="get(nameServers[0])" 2>/dev/null)
    export APIGEECTL_HOME=$PWD/tools/apigeectl/apigeectl_$APIGEE_CTL_VERSION
    export HYBRID_HOME=$PWD/hybrid-files
}

token() { echo -n "$(gcloud config config-helper --force-auth-refresh | grep access_token | grep -o -E '[^ ]+$')" ; }

function wait_for_ready(){
    local expected_status=$1
    local action=$2
    local message=$3
    local max_iterations=120 # 10min
    local iterations=0

    echo -e "Start: $(date)\n"

    while true; do
        ((iterations++))

        local signal=$(eval "$action")
        if [ $(echo "$expected_status") = "$signal" ]; then
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

  echo "📝 Enabling all required APIs"
  
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
    wait_for_ready "0" 'curl --silent -H "Authorization: Bearer $(token)" -H "Content-Type: application/json"  https://apigee.googleapis.com/v1/organizations/$PROJECT_ID | grep "subscriptionType" > /dev/null  2>&1; echo $?' "Organization $PROJECT_ID is created."

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
      https://apigee.googleapis.com/v1/organizations/"$PROJECT_ID"/environments

    echo -n "⏳ Waiting for Apigeectl Env Creation "
    wait_for_ready "0" 'curl --silent -H "Authorization: Bearer $(token)" -H "Content-Type: application/json"  https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/environments/$ENV_NAME | grep "$ENV_NAME" > /dev/null  2>&1; echo $?' "Environment $ENV_NAME of Organization $PROJECT_ID is created."

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
      https://apigee.googleapis.com/v1/organizations/"$PROJECT_ID"/envgroups

    echo -n "⏳ Waiting for Apigeectl Env Creation "
    wait_for_ready "0" 'curl --silent -H "Authorization: Bearer $(token)" -H "Content-Type: application/json"  https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/envgroups/$ENV_GROUP_NAME | grep $ENV_GROUP_NAME > /dev/null  2>&1; echo $?' "Environment Group $ENV_GROUP_NAME of Organization $PROJECT_ID is created."

    echo "✅ Created Env Group '$ENV_GROUP_NAME'"
}

add_env_to_envgroup() {
  ENV_NAME=$1
  ENV_GROUP_NAME=$2

  echo "🚀 Adding Env $ENV_NAME to Env Group $ENV_GROUP_NAME"

  curl -H "Authorization: Bearer $(token)" -X POST -H "content-type:application/json" \
   -d '{
     "environment": "'"$ENV_NAME"'",
   }' \
   "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/envgroups/$ENV_GROUP_NAME/attachments"
  
  echo "✅ Added Env $ENV_NAME to Env Group $ENV_GROUP_NAME"


}

configure_network() {
    echo "🌐 Setup Networking"

    gcloud compute addresses create apigee-ingress-loadbalancer --region $REGION

    gcloud dns managed-zones create apigee-dns-zone --dns-name="$DNS_NAME" --description=apigee-dns-zone

    export INGRESS_IP=$(gcloud compute addresses list --format json --filter "name=apigee-ingress-loadbalancer" --format="get(address)")

    gcloud dns record-sets transaction start --zone=apigee-dns-zone

    gcloud dns record-sets transaction add "$INGRESS_IP" \
        --name=api."$DNS_NAME". --ttl=600 \
        --type=A --zone=apigee-dns-zone

    gcloud dns record-sets transaction describe --zone=apigee-dns-zone
    gcloud dns record-sets transaction execute --zone=apigee-dns-zone

    export NAME_SERVER=$(gcloud dns managed-zones describe apigee-dns-zone --format="json" --format="get(nameServers[0])")
    echo "👋 Add this as an NS record for $DNS_NAME: $NAME_SERVER"
    echo "✅ Networking set up"
}

create_gke_cluster() {
    echo "🚀 Create GKE cluster"

    gcloud container clusters create $CLUSTER_NAME \
      --cluster-version "1.16.13-gke.1" \
      --machine-type "e2-standard-4" \
      --num-nodes "4" \
      --enable-autoscaling --min-nodes "3" --max-nodes "6" \
      --labels mesh_id="${MESH_ID}" \
      --workload-pool "${WORKLOAD_POOL}" \
      --enable-stackdriver-kubernetes


    gcloud container clusters get-credentials $CLUSTER_NAME

    kubectl create clusterrolebinding cluster-admin-binding \
      --clusterrole cluster-admin --user $(gcloud config get-value account)

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
  gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} 2>/dev/null

  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
   --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
   --role="roles/gkehub.connect"

  SERVICE_ACCOUNT_KEY_PATH=/tmp/$SERVICE_ACCOUNT_NAME.json

  gcloud iam service-accounts keys create ${SERVICE_ACCOUNT_KEY_PATH} \
   --iam-account=${SERVICE_ACCOUNT_NAME}@"${PROJECT_ID}".iam.gserviceaccount.com

  gcloud container hub memberships register $CLUSTER_NAME \
    --gke-cluster=${ZONE}/${CLUSTER_NAME} \
    --service-account-key-file=${SERVICE_ACCOUNT_KEY_PATH}

  rm $SERVICE_ACCOUNT_KEY_PATH

  echo "🏗️ Installing Anthos Service Mesh"
  mkdir -p ./tools/istio-asm
  curl -L -o ./tools/istio-asm/istio-asm.tar.gz "https://storage.googleapis.com/gke-release/asm/${ISTIO_ASM_CLI}"
  tar xzf ./tools/istio-asm/istio-asm.tar.gz -C ./tools/istio-asm
  mv ./tools/istio-asm/istio-*/* ./tools/istio-asm/.

  mkdir -p ./tools/kpt
  curl -L -o ./tools/kpt/kpt.tar.gz "https://github.com/GoogleContainerTools/kpt/releases/download/${KPT_VERSION}/${KPT_BINARY}"
  tar xzf ./tools/kpt/kpt.tar.gz -C ./tools/kpt

  echo "🩹 Patching the ASM Config"

  cd ./tools/kpt || exit
  ./kpt pkg get \
https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git/asm@release-1.5-asm .

  ./kpt cfg set asm gcloud.container.cluster ${CLUSTER_NAME}
  ./kpt cfg set asm gcloud.core.project "${PROJECT_ID}" 
  ./kpt cfg set asm gcloud.compute.location ${ZONE}

  # Apply Apigee config to ASM Config
  
  sed 's/clusterName: \(.*\)/clusterName: \1\
  name: asm-istio-operator/' ./asm/cluster/istio-operator.yaml > ./asm/cluster/istio-operator-with-name.yaml

  cat <<EOF > kustomization.yaml 
resources:
- ./asm/cluster/istio-operator-with-name.yaml
patchesStrategicMerge:
- apigee-asm-mesh-config.yaml
- apigee-asm-ingress-ip.yaml
EOF

cat <<EOF > apigee-asm-mesh-config.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: asm-istio-operator
spec:
  meshConfig:
    # This disables Istio from configuring workloads for mTLS if TLSSettings are not specified. 1.4 defaulted to false.
    enableAutoMtls: false
    accessLogFile: "/dev/stdout"
    accessLogEncoding: 1
    # This is Apigee's custom access log format. Changes should not be made to this
    # unless first working with the Data and AX teams as they parse these logs for
    # SLOs.
    accessLogFormat: '{"start_time":"%START_TIME%","remote_address":"%DOWNSTREAM_DIRECT_REMOTE_ADDRESS%","user_agent":"%REQ(USER-AGENT)%","host":"%REQ(:AUTHORITY)%","request":"%REQ(:METHOD)%
      %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%","request_time":"%DURATION%","status":"%RESPONSE_CODE%","status_details":"%RESPONSE_CODE_DETAILS%","bytes_received":"%BYTES_RECEIVED%","bytes_sent":"%BYTES_SENT%","upstream_address":"%UPSTREAM_HOST%","upstream_response_flags":"%RESPONSE_FLAGS%","upstream_response_time":"%RESPONSE_DURATION%","upstream_service_time":"%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%","upstream_cluster":"%UPSTREAM_CLUSTER%","x_forwarded_for":"%REQ(X-FORWARDED-FOR)%","request_method":"%REQ(:METHOD)%","request_path":"%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%","request_protocol":"%PROTOCOL%","tls_protocol":"%DOWNSTREAM_TLS_VERSION%","request_id":"%REQ(X-REQUEST-ID)%","sni_host":"%REQUESTED_SERVER_NAME%","apigee_dynamic_data":"%DYNAMIC_METADATA(envoy.lua)%"}'
EOF

cat <<EOF > apigee-asm-ingress-ip.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: asm-istio-operator
spec:
  components:
    pilot:
      k8s:
        hpaSpec:
          maxReplicas: 3
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
        k8s:
          service:
            type: LoadBalancer
            loadBalancerIP: $INGRESS_IP
            ports:
              - name: status-port
                port: 15020
                targetPort: 15020
              - name: http2
                port: 80
                targetPort: 80
              - name: https
                port: 443
              - name: prometheus
                port: 15030
                targetPort: 15030
              - name: tcp
                port: 31400
                targetPort: 31400
              - name: tls
                port: 15443
                targetPort: 15443
          hpaSpec:
            maxReplicas: 3
EOF

  kubectl kustomize ./ > ./asm/cluster/istio-operator-patched.yaml

  ../istio-asm/bin/istioctl manifest apply --set profile=asm \
    -f asm/cluster/istio-operator-patched.yaml

  cd ../..

  echo "✅ ASM installed"

}

download_apigee_ctl() {
    echo "📥 Setup Apigeectl"

    mkdir -p ./tools/apigeectl
    curl -L \
      -o ./tools/apigeectl/apigeectl.tar.gz \
      "https://storage.googleapis.com/apigee-public/apigee-hybrid-setup/$APIGEE_CTL_VERSION/$APIGEE_CTL"

    tar xvzf ./tools/apigeectl/apigeectl.tar.gz -C ./tools/apigeectl
    rm ./tools/apigeectl/apigeectl.tar.gz
    mkdir -p "$APIGEECTL_HOME"
    mv ./tools/apigeectl/apigeectl_*_64/* "$APIGEECTL_HOME"
    rm -d ./tools/apigeectl/apigeectl_*_64
    echo "✅ Apigeectl set up in $APIGEECTL_HOME"
}

prepare_resources() {
    echo "🛠️ Configure Apigee hybrid"

    if [ -d "hybrid-files" ]; then rm -Rf hybrid-files; fi
    mkdir -p "$HYBRID_HOME" && cd "$HYBRID_HOME" || exit

    mkdir -p overrides
    mkdir  -p service-accounts
    mkdir  -p certs
    ln -s "$APIGEECTL_HOME"/tools tools
    ln -s "$APIGEECTL_HOME"/config config
    ln -s "$APIGEECTL_HOME"/templates templates
    ln -s "$APIGEECTL_HOME"/plugins plugins

    echo "🙈 Creating self-signed certs"
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj "/CN=$DNS_NAME/O=Apigee Quickstart" -keyout ./certs/"$DNS_NAME".key -out ./certs/"$DNS_NAME".crt
    openssl req -out ./certs/api."$DNS_NAME".csr -newkey rsa:2048 -nodes -keyout ./certs/api."$DNS_NAME".key -subj "/CN=api.$DNS_NAME/O=Apigee Quickstart"
    openssl x509 -req -days 365 -CA ./certs/"$DNS_NAME".crt -CAkey ./certs/"$DNS_NAME".key -set_serial 0 -in ./certs/api."$DNS_NAME".csr -out ./certs/api."$DNS_NAME".crt
    cat ./certs/api."$DNS_NAME".crt ./certs/"$DNS_NAME".crt > ./certs/api."$DNS_NAME".fullchain.crt
    
    kubectl create -n istio-system secret generic "$PROJECT_ID"-default  \
      --from-file=key=./certs/api."$DNS_NAME".key \
      --from-file=cert=./certs/api."$DNS_NAME".fullchain.crt

    echo "✅ Hybrid Config Setup"
}

create_sa() {
    for SA in mart cassandra udca metrics synchronizer logger watcher
    do
      yes | "$APIGEECTL_HOME"/tools/create-service-account apigee-$SA "$HYBRID_HOME"/service-accounts
    done
}

install_runtime() {
    echo "Configure Overrides"
    cd "$HYBRID_HOME" || exit
    cat << EOF > ./overrides/overrides.yaml
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
  - name: default
    sslSecret: $PROJECT_ID-default

instanceID: "$PROJECT_ID-$(date +%s)"

envs:
  - name: test
    serviceAccountPaths:
      synchronizer: ./service-accounts/$PROJECT_ID-apigee-synchronizer.json
      udca: ./service-accounts/$PROJECT_ID-apigee-udca.json

mart:
  serviceAccountPath: ./service-accounts/$PROJECT_ID-apigee-mart.json

connectAgent:
  serviceAccountPath: ./service-accounts/$PROJECT_ID-apigee-mart.json

metrics:
  enabled: true
  serviceAccountPath: ./service-accounts/$PROJECT_ID-apigee-metrics.json

watcher:
  serviceAccountPath: ./service-accounts/$PROJECT_ID-apigee-watcher.json
EOF

    mkdir -p generated
    "$APIGEECTL_HOME"/apigeectl init -f overrides/overrides.yaml --print-yaml > ./generated/apigee-init.yaml
    echo -n "⏳ Waiting for Apigeectl init "
    wait_for_ready "0" '$APIGEECTL_HOME/apigeectl check-ready -f overrides/overrides.yaml > /dev/null  2>&1; echo $?' "apigeectl init: done."


    "$APIGEECTL_HOME"/apigeectl apply -f overrides/overrides.yaml --dry-run=true 
    "$APIGEECTL_HOME"/apigeectl apply -f overrides/overrides.yaml --print-yaml > ./generated/apigee-runtime.yaml

    echo -n "⏳ Waiting for Apigeectl apply "
    wait_for_ready "0" '$APIGEECTL_HOME/apigeectl check-ready -f overrides/overrides.yaml > /dev/null  2>&1; echo $?' "apigeectl apply: done."

    curl -X POST -H "Authorization: Bearer $(token)" \
    -H "Content-Type:application/json" \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}:setSyncAuthorization" \
    -d "{\"identities\":[\"serviceAccount:apigee-synchronizer@${PROJECT_ID}.iam.gserviceaccount.com\"]}"

    cd ..

    echo "🎉🎉🎉 Hybrid installation completed!"

}

deploy_example_proxy() {
  echo "🦄 Deploy Sample Proxy"
  (cd example-proxy && zip -r apiproxy.zip apiproxy/*) 

  PROXY_REV=$(curl -X POST \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}/apis?action=import&name=httpbin-v0&validate=true" \
    -H "Authorization: Bearer $(token)" \
    -H "Content-Type: multipart/form-data" \
    -F 'zipFile=@./example-proxy/apiproxy.zip' | grep '"revision": "[^"]*' | cut -d'"' -f4)
  
  rm example-proxy/apiproxy.zip

  curl -X POST \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}/environments/test/apis/httpbin-v0/revisions/${PROXY_REV}/deployments?override=true" \
    -H "Authorization: Bearer $(token)"
  
  echo "✅ Sample Proxy Deployed"

  echo "🤓 Try without DNS (first deployment takes a few seconds. Relax and breathe!):"
  echo "curl --cacert ./hybrid-files/certs/$DNS_NAME.crt --resolve api.$DNS_NAME:443:$INGRESS_IP https://api.$DNS_NAME/httpbin/v0/anything"

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
  for SA_KEY_NAME in $(gcloud iam service-accounts keys list --iam-account="${SA}"@"${PROJECT_ID}".iam.gserviceaccount.com --format="get(name)")
  do
    gcloud iam service-accounts keys delete "$SA_KEY_NAME" --iam-account="$SA"@"$PROJECT_ID".iam.gserviceaccount.com -q
  done
}
