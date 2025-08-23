#!/bin/bash

# Copyright 2022 Google LLC
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

# Default values
APIGEE_VERSION="1.14.2-hotfix.1"
APIGEE_NAMESPACE="apigee"

# Function to display usage
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -v, --version VERSION        Apigee version (default: $APIGEE_VERSION)"
    echo "  -n, --namespace NAMESPACE    Apigee namespace (default: $APIGEE_NAMESPACE)"
    echo "  -f, --kubeconfig KUBECONFIG  Path to kubeconfig file (default: $KUBECONFIG)"
    echo "  -o, --overrides PATH        Path to overrides.yaml file (required)"
    echo "  -s, --service PATH          Path to apigee service template file (required)"
    echo "  -a, --sa_email SA_EMAIL      Path to apigee service accounts template file (required)"
    echo "  -k, --key PATH              Path to service account key JSON file (required)"
    echo "  -c, --cert PATH             Path to environment group certificate file (required)"
    echo "  -p, --private-key PATH      Path to environment group private key file (required)"
    echo "  -h, --help                  Display this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            APIGEE_VERSION="$2"
            shift 2
            ;;
        -n|--namespace)
            APIGEE_NAMESPACE="$2"
            shift 2
            ;;
        -f|--kubeconfig)
            KUBECONFIG_FILE="$2"
            shift 2
            ;;
        -o|--overrides)
            OVERRIDES_YAML_PATH="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE_TEMPLATE_PATH="$2"
            shift 2
            ;;
        -a|--sa_email)
            SA_EMAIL="$2"
            shift 2
            ;;
        -k|--key)
            SA_KEY_JSON_PATH="$2"
            shift 2
            ;;
        -c|--cert)
            ENVGROUP_CERT_PATH="$2"
            shift 2
            ;;
        -p|--private-key)
            ENVGROUP_PRIVATE_KEY_PATH="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done


# Validate required parameters
if [ -z "$OVERRIDES_YAML_PATH" ] || [ -z "$SERVICE_TEMPLATE_PATH" ] || [ -z "$SA_EMAIL" ] || \
   [ -z "$SA_KEY_JSON_PATH" ] || [ -z "$ENVGROUP_CERT_PATH" ] || \
   [ -z "$ENVGROUP_PRIVATE_KEY_PATH" ]; then
    echo "Error: Missing required parameters"
    usage
fi

setup_apigee() {
    if [ -z "$APIGEE_NAMESPACE" ]; then
        echo "Apigee namespace is required"
        exit 1
    fi

    if [ -z "$OVERRIDES_YAML_PATH" ]; then
        echo "Apigee overrides YAML is required"
        exit 1
    fi

    if [ -z "$SA_KEY_JSON_PATH" ]; then
        echo "Apigee SA key JSON is required"
        exit 1
    fi

    if [ -z "$ENVGROUP_CERT_PATH" ]; then
        echo "Apigee envgroup cert file is required"
        exit 1
    fi

    if [ -z "$ENVGROUP_PRIVATE_KEY_PATH" ]; then
        echo "Apigee envgroup private key file is required"
        exit 1
    fi

    if [ -z "$SERVICE_TEMPLATE_PATH" ]; then
        echo "Apigee service template path is required"
        exit 1
    fi

    org_name=$(grep -A 1 'org:' "$OVERRIDES_YAML_PATH" | grep 'org:' | awk '{print $2}')
    export org_name

    # Set up base directories
    export APIGEE_HYBRID_BASE=output/$org_name/apigee-hybrid
    export APIGEE_HELM_CHARTS_BASE=helm-charts

    mkdir -p "$APIGEE_HYBRID_BASE/$APIGEE_HELM_CHARTS_BASE"

    # Pull Apigee Helm charts
    cd "$APIGEE_HYBRID_BASE/$APIGEE_HELM_CHARTS_BASE" || exit
    export APIGEE_HELM_CHARTS_HOME=$PWD

    # Set chart repository and version
    export CHART_REPO=oci://us-docker.pkg.dev/apigee-release/apigee-hybrid-helm-charts
    export CHART_VERSION=${APIGEE_VERSION}

    # Remove all files in the home directory
    rm -rf "${APIGEE_HELM_CHARTS_HOME:?}"/*

    # Pull all required Helm charts
    helm pull "$CHART_REPO/apigee-operator" --version "$CHART_VERSION" --untar
    helm pull "$CHART_REPO/apigee-datastore" --version "$CHART_VERSION" --untar
    helm pull "$CHART_REPO/apigee-env" --version "$CHART_VERSION" --untar
    helm pull "$CHART_REPO/apigee-ingress-manager" --version "$CHART_VERSION" --untar
    helm pull "$CHART_REPO/apigee-org" --version "$CHART_VERSION" --untar
    helm pull "$CHART_REPO/apigee-redis" --version "$CHART_VERSION" --untar
    helm pull "$CHART_REPO/apigee-telemetry" --version "$CHART_VERSION" --untar
    helm pull "$CHART_REPO/apigee-virtualhost" --version "$CHART_VERSION" --untar

    # Get the filename from the path
    apigee_overrides_yaml_filename=$(basename "$OVERRIDES_YAML_PATH")
    local apigee_overrides_yaml_filename
    apigee_service_template_filename=$(basename "$SERVICE_TEMPLATE_PATH")
    local apigee_service_template_filename
    apigee_sa_key_json_filename=$(basename "$SA_KEY_JSON_PATH")
    local apigee_sa_key_json_filename
    apigee_envgroup_cert_file_filename=$(basename "$ENVGROUP_CERT_PATH")
    local apigee_envgroup_cert_file_filename
    apigee_envgroup_private_key_file_filename=$(basename "$ENVGROUP_PRIVATE_KEY_PATH")
    local apigee_envgroup_private_key_file_filename

    echo "apigee_overrides_yaml_filename: $apigee_overrides_yaml_filename"
    echo "apigee_sa_key_json_filename: $apigee_sa_key_json_filename"
    echo "apigee_envgroup_cert_file_filename: $apigee_envgroup_cert_file_filename"
    echo "apigee_envgroup_private_key_file_filename: $apigee_envgroup_private_key_file_filename"
    
    # Copy the overrides.yaml file
    cp "$OVERRIDES_YAML_PATH" "$APIGEE_HELM_CHARTS_HOME/$apigee_overrides_yaml_filename"
    cp "$SERVICE_TEMPLATE_PATH" "$APIGEE_HELM_CHARTS_HOME/$apigee_service_template_filename"

    # Copy the sa-key.json file
    cp -fr "$SA_KEY_JSON_PATH" "$APIGEE_HELM_CHARTS_HOME/apigee-datastore/$apigee_sa_key_json_filename"
    cp -fr "$SA_KEY_JSON_PATH" "$APIGEE_HELM_CHARTS_HOME/apigee-telemetry/$apigee_sa_key_json_filename"
    cp -fr "$SA_KEY_JSON_PATH" "$APIGEE_HELM_CHARTS_HOME/apigee-org/$apigee_sa_key_json_filename"
    cp -fr "$SA_KEY_JSON_PATH" "$APIGEE_HELM_CHARTS_HOME/apigee-env/$apigee_sa_key_json_filename"

    mkdir -p "$APIGEE_HELM_CHARTS_HOME/apigee-virtualhost/certs/"

    # Copy the cert files
    cp -fr "$ENVGROUP_CERT_PATH" "$APIGEE_HELM_CHARTS_HOME/apigee-virtualhost/certs/$apigee_envgroup_cert_file_filename"
    cp -fr "$ENVGROUP_PRIVATE_KEY_PATH" "$APIGEE_HELM_CHARTS_HOME/apigee-virtualhost/certs/$apigee_envgroup_private_key_file_filename"
}

create_namespace() {
    local apigee_namespace=$1
    if ! kubectl get namespace "$apigee_namespace" &>/dev/null; then
        kubectl create namespace "$apigee_namespace"
    fi
}

enable_control_plane_access() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2
    org_name=$(grep -A 1 'org:' "$apigee_overrides_yaml_path" | grep 'org:' | awk '{print $2}')
    local org_name

    TOKEN=$(gcloud auth application-default print-access-token)
    export TOKEN

    curl -X PATCH -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type:application/json" \
    "https://apigee.googleapis.com/v1/organizations/$org_name/controlPlaneAccess?update_mask=synchronizer_identities" \
    -d "{\"synchronizer_identities\": [\"serviceAccount:$SA_EMAIL\"]}"
    
    sleep 5

    curl -X  PATCH -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type:application/json" \
    "https://apigee.googleapis.com/v1/organizations/$org_name/controlPlaneAccess?update_mask=analytics_publisher_identities" \
    -d "{\"analytics_publisher_identities\": [\"serviceAccount:$SA_EMAIL\"]}"

}

install_crd() {
    kubectl apply -k  "$APIGEE_HELM_CHARTS_HOME/apigee-operator/etc/crds/default/" \
    --server-side \
    --force-conflicts \
    --validate=false
}

install_cert_manager() {
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.3/cert-manager.yaml

    #Wait for cert-manager to be ready
    kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=120s
}

install_operator() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    cd "$APIGEE_HELM_CHARTS_HOME" || exit

    helm upgrade operator apigee-operator/ \
    --install \
    --namespace "$apigee_namespace" \
    --atomic \
    -f "$apigee_overrides_yaml_path"

    #Wait for operator to be ready
    kubectl wait --for=condition=ready pod -l app=apigee-controller -n "$apigee_namespace" --timeout=120s
}

install_datastore() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    cd "$APIGEE_HELM_CHARTS_HOME" || exit

    helm upgrade datastore apigee-datastore/ \
    --install \
    --namespace "$apigee_namespace" \
    --atomic \
    -f "$apigee_overrides_yaml_path"
}

install_telemetry() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    cd "$APIGEE_HELM_CHARTS_HOME" || exit

    helm upgrade telemetry apigee-telemetry/ \
    --install \
    --namespace "$apigee_namespace" \
    --atomic \
    -f "$apigee_overrides_yaml_path"
}

install_redis() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    cd "$APIGEE_HELM_CHARTS_HOME" || exit

    helm upgrade redis apigee-redis/ \
    --install \
    --namespace "$apigee_namespace" \
    --atomic \
    -f "$apigee_overrides_yaml_path"
}

install_ingress_manager() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    cd "$APIGEE_HELM_CHARTS_HOME" || exit

    helm upgrade ingress-manager apigee-ingress-manager/ \
    --install \
    --namespace "$apigee_namespace" \
    --atomic \
    -f "$apigee_overrides_yaml_path"
}

install_org() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2
    org_name=$(grep -A 1 'org:' "$apigee_overrides_yaml_path" | grep 'org:' | awk '{print $2}')
    local org_name

    cd "$APIGEE_HELM_CHARTS_HOME" || exit

    helm upgrade "$org_name" apigee-org/ \
    --install \
    --namespace "$apigee_namespace" \
    --atomic \
    -f "$apigee_overrides_yaml_path"
}

install_env() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    #read the env_name from the overrides.yaml file
    apigee_env_name=$(grep -A 1 'envs:' "$apigee_overrides_yaml_path" | grep 'name:' | awk '{print $3}')
    local apigee_env_name

    local env_release_name="env-release-$apigee_env_name"
    cd "$APIGEE_HELM_CHARTS_HOME" || exit

    helm upgrade "$env_release_name" apigee-env/ \
    --install \
    --namespace "$apigee_namespace" \
    --atomic \
    --set env="$apigee_env_name" \
    -f "$apigee_overrides_yaml_path"
    
}

install_envgroup() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    #read the env_group_name from the overrides.yaml file
    apigee_env_group_name=$(grep -A 1 'virtualhosts:' "$apigee_overrides_yaml_path" | grep 'name:' | awk '{print $3}')
    local apigee_env_group_name
    local env_group_release_name="env-group-release-$apigee_env_group_name"

    helm upgrade "$env_group_release_name" apigee-virtualhost/ \
    --install \
    --namespace "$apigee_namespace" \
    --atomic \
    --set envgroup="$apigee_env_group_name" \
    -f "$apigee_overrides_yaml_path"
    
}   

setup_ingress() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    cd "$APIGEE_HELM_CHARTS_HOME" || exit

    #apply the apigee-service.yaml file
    kubectl apply -f "$APIGEE_HELM_CHARTS_HOME/apigee-service.yaml"
    
}

setup_kubeconfig() {

    if [ -z "$KUBECONFIG_FILE" ]; then
        echo "KUBECONFIG_FILE is not set. Will use default kubeconfig"
    else
        if [ -f "$KUBECONFIG_FILE" ]; then
            export KUBECONFIG=$KUBECONFIG_FILE
        else
            echo "KUBECONFIG_FILE does not exist"
        fi
    fi
    echo "Checking if kubectl is configured correctly"
    if ! kubectl get nodes; then
        echo "Failed to get nodes"
        exit 1
    fi
}

# Main function
main() {
    setup_apigee
    setup_kubeconfig
    create_namespace "$APIGEE_NAMESPACE"
    enable_control_plane_access "$APIGEE_NAMESPACE" "overrides.yaml"
    install_crd
    install_cert_manager
    install_operator "$APIGEE_NAMESPACE" "overrides.yaml"
    install_datastore "$APIGEE_NAMESPACE" "overrides.yaml"
    install_telemetry "$APIGEE_NAMESPACE" "overrides.yaml"
    install_redis "$APIGEE_NAMESPACE" "overrides.yaml"
    install_ingress_manager "$APIGEE_NAMESPACE" "overrides.yaml"
    install_org "$APIGEE_NAMESPACE" "overrides.yaml"
    install_env "$APIGEE_NAMESPACE" "overrides.yaml"
    install_envgroup "$APIGEE_NAMESPACE" "overrides.yaml"
    setup_ingress "$APIGEE_NAMESPACE" "overrides.yaml"
}

# Run main function
main
