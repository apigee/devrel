#!/bin/bash
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    --action)
    ACTION="$2"
    shift # past argument
    shift # past value
    ;;
    --apigee-token)
    GCLOUD_APIGEE_TOKEN="$2"
    shift # past argument
    shift # past value
    ;;
    --apigee-org)
    APIGEE_ORG="$2"
    shift # past argument
    shift # past value
    ;;
    --apigee-env)
    APIGEE_ENV="$2"
    shift # past argument
    shift # past value
    ;;
    --gcp-apigee-project)
    GPROJECT_APIGEE="$2"
    shift # past argument
    shift # past value
    ;;
    --gcp-project)
    GPROJECT_GCP="$2"
    shift # past argument
    shift # past value
    ;;
    --appengine)
    APPENGINE="$2"
    shift # past argument
    shift # past value
    ;;
    --apigee-url)
    APIGEE_URL="$2"
    shift # past argument
    shift # past value
    ;;
    --appengine-domain)
    APPENGINE_DOMAIN_NAME="$2"
    shift # past argument
    shift # past value
    ;;
    --gcp-svc-account-email)
    GCP_SVC_ACCOUNT_EMAIL="$2"
    shift # past argument
    shift # past value
    ;;
    --deployment)
    DEPLOYMENT=$2
    shift # past argument
    shift # past value
    ;;
    --workload-level)
    WORKLOAD_LEVEL="$2"
    shift # past argument
    shift # past value
    ;;
    --uuid)
    RAND="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [ -z "$ACTION" ]; then 
    ERROR_PARAMETER="--action"
fi
if [ -z "$GCLOUD_APIGEE_TOKEN" ]; then 
    ERROR_PARAMETER="--apigee-token"
    
fi
if [ -z "$APIGEE_ORG" ]; then
    ERROR_PARAMETER="--apigee-org"
    
fi
if [ -z "$APIGEE_ENV" ]; then
    ERROR_PARAMETER="--apigee-env"
fi
if [ -z "$GPROJECT_APIGEE" ]; then
    ERROR_PARAMETER="--gcp-apigee-project"
    
fi
if [ -z "$GPROJECT_GCP" ]; then
    ERROR_PARAMETER="--gcp-project"
    
fi
if [ -z "$APIGEE_URL" ]; then
    ERROR_PARAMETER="--apigee-url"
    
fi
if [ -z "$RAND" ]; then
    ERROR_PARAMETER="--uuid"
    
fi
if [ -z "$DEPLOYMENT" ]; then
    ERROR_PARAMETER="--deployment"
fi
if [ ! -z $ERROR_PARAMETER ]; then
    echo "Error: The parameter $ERROR_PARAMETER is empty or wrong. Please follow these instructions to run the script:"
    exit
fi

echo "INIT --> Apigee Org: $APIGEE_ORG"
echo "INIT --> Apigee Env: $APIGEE_ENV"
echo "INIT --> GCP Apigee Project: $GPROJECT_APIGEE"
echo "INIT --> GCP Project: $GPROJECT_GCP"
echo "INIT --> Apigee Url: $APIGEE_URL"
echo "INIT --> GCP Serv Domain: $GCP_SVC_ACCOUNT_EMAIL"
echo "INIT --> UUID: $RAND"
echo "INIT --> What to deployment: $DEPLOYMENT"
echo "INIT --> Workload Level: $WORKLOAD_LEVEL"

docker build \
   -t local/load-generator-init:2.0.0 .

docker run \
    --env ACTION=$ACTION \
    --env GCLOUD_APIGEE_TOKEN=$GCLOUD_APIGEE_TOKEN \
    --env APIGEE_ORG=$APIGEE_ORG \
    --env APIGEE_ENV=$APIGEE_ENV\
    --env GPROJECT_APIGEE=$GPROJECT_APIGEE\
    --env GPROJECT_GCP=$GPROJECT_GCP \
    --env APIGEE_URL=$APIGEE_URL \
    --env RAND=$RAND \
    --env DEPLOYMENT=$DEPLOYMENT \
    --env WORKLOAD_LEVEL=$WORKLOAD_LEVEL \
local/load-generator-init:2.0.0