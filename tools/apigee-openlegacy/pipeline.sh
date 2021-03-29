#!/bin/sh
# Copyright 2021 Google LLC
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

set -e

if [ -z "$OPENLEGACY_HOST" ]; then
  echo "OpenLegacy backend not found - skipping pipeline"
  exit 0
fi

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

mkdir -p "$SCRIPTPATH"/pipeline-workspace
cd "$SCRIPTPATH"/pipeline-workspace

# Install OpenLegacy cli
if ! [ -f "$SCRIPTPATH"/pipeline-workspace/openlegacy-cli.zip ]; then
  curl -O https://ol-public-artifacts.s3.amazonaws.com/openlegacy-cli/1.30.0/linux-macos/openlegacy-cli.zip
  unzip openlegacy-cli.zip
fi

# call the script with ol and gcloud on our path
PATH="$PATH":"$SCRIPTPATH"/pipeline-workspace/ol/bin:/google-cloud-sdk/bin \
  sh "$SCRIPTPATH"/bin/apigee-openlegacy.sh
