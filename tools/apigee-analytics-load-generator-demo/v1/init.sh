

docker build \
   -t local/load-generator-init:1.0.0 .
docker run \
    --env ACTION=${1} \
    --env APIGEE_USER=${2} \
    --env APIGEE_PASS=${3} \
    --env APIGEE_ORG=${4} \
    --env APIGEE_ENV=${5} \
    --env GPROJECT=${6} \
    --env APPENGINE=${7} \
    --env APIGEE_URL=${8} \
    --env APPENGINE_DOMAIN_NAME=${9} \
    --env GCP_SVC_ACCOUNT_EMAIL=${10} \
    --env RAND=${11} \
local/load-generator-init:1.0.0