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


###############################################################################
# Script to ensure health of instructions through nightly builds
# Safe to ignore for the purposes of the intended solution/lab
###############################################################################

set -e

PROJECT_ID="$(gcloud config get-value project)"

echo "[INFO] CI and artifact storage using Cloud Build"
SUBSTITUTIONS_X="_APIGEE_ORG=$APIGEE_X_ORG"
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_APIGEE_ENV=$APIGEE_X_ENV"
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_APIGEE_RUNTIME_HOST=$APIGEE_X_HOSTNAME"
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_APIGEE_BUILD_BUCKET=${PROJECT_ID}_cloudbuild"
gcloud builds submit --config=./cloudbuild.yaml \
  --substitutions="$SUBSTITUTIONS_X"
