#!/bin/sh

set -e

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

mkdir -p $SCRIPTPATH/pipeline-workspace
cd $SCRIPTPATH/pipeline-workspace

# Install OpenLegacy cli
if ! [ -f $SCRIPTPATH/pipeline-workspace/openlegacy-cli.zip ]; then
  curl -O https://ol-public-artifacts.s3.amazonaws.com/openlegacy-cli/1.30.0/linux-macos/openlegacy-cli.zip
  unzip openlegacy-cli.zip
fi

# call the script with ol and gcloud on our path
PATH=$PATH:$SCRIPTPATH/pipeline-workspace/ol/bin:/google-cloud-sdk/bin \
  sh $SCRIPTPATH/bin/apigee-openlegacy.sh
