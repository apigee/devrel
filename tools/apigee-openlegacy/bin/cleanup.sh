#!/bin/sh

# A script to clean up entities that can't be updated - errors may indicate that entities are already removed
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
PATH="$PATH":"$SCRIPTPATH"/../pipeline-workspace/ol/bin:/google-cloud-sdk/bin

# Cleanup OpenLegacy Assets
ol login --api-key "$OPENLEGACY_APIKEY"
ol delete project aok-project
ol delete module aok-module

# Cleanup Apigee Assets - TODO switch to sackmesser for 5g cleanup
npx apigeetool deleteApp -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" --name "AOKApp"
npx apigeetool deleteDeveloper -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" --email "aok@example.com"
npx apigeetool deleteProduct -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" --productName "ApigeeOpenLegacy"
npx apigeetool undeploy -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" -n "aok-v1"
npx apigeetool delete -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -n "aok-v1"
npx apigeetool undeploySharedflow -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" -n "gcp-sa-auth-v1"
npx apigeetool deleteSharedFlow -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -n "gcp-sa-auth-v1"
npx apigeetool deletecache -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" -z "gcp-tokens"
npx apigeetool deletekvmmap -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" --mapName "aok-service-accounts"

# Cleanup  GCP Assets
gcloud iam service-accounts delete aok-sa@"$GCP_PROJECT".iam.gserviceaccount.com --project "$GCP_PROJECT" -q

