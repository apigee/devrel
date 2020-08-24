#!/bin/bash

source ./steps.sh

set_config_params

echo "🗑️ Delete Apigee hybrid cluster"

gcloud container hub memberships unregister $CLUSTER_NAME --gke-cluster=${ZONE}/${CLUSTER_NAME}
yes | gcloud container clusters delete $CLUSTER_NAME

echo "✅ Apigee hybrid cluster deleted"


echo "🗑️ Clean up Networking"

yes | gcloud compute addresses delete api --region $REGION

touch empty-file
gcloud dns record-sets import -z hybridlab \
   --delete-all-existing \
   empty-file
rm empty-file

yes | gcloud dns managed-zones delete hybridlab

echo "✅ Apigee networking cleaned up"

rm -rd ./tools
rm -rd ./hybrid-files

echo "✅ Tooling and Config removed"

delete_apigee_keys
delete_sa_keys "$CLUSTER_NAME-anthos-connect"
delete_sa_keys "dns01-solver"

echo "✅ SA keys deleted"


echo "✅ ✅ ✅ Clean up completed"