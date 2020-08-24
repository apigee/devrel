#!/bin/bash

source ./steps.sh

set_config_params

echo "🗑️ Delete Apigee hybrid cluster"

yes | gcloud container clusters delete $CLUSTER_NAME
echo "✅ Apigee hybrid cluster deleted"


echo "🗑️ Clean up Networking"

yes | gcloud compute addresses delete mart-ip --region $REGION
yes | gcloud compute addresses delete api --region $REGION

touch empty-file
gcloud dns record-sets import -z hybridlab \
   --delete-all-existing \
   empty-file
rm empty-file

yes | gcloud dns managed-zones delete hybridlab

echo "✅ Apigee networking cleaned up"

rm -rd apigeectl_*
rm -rd ./hybrid-files
