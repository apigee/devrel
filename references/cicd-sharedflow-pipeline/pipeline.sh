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
set -x

# Apigee X/hybrid

TOKEN=$(gcloud auth print-access-token)

# Deploy the sharedflow
mvn clean install -Pgoogleapi -Dorg="$APIGEE_X_ORG" \
-Denv="$APIGEE_X_ENV" -Dtoken="$TOKEN"

# Deploy the proxy to test the shareflow
mvn clean install -Pgoogleapi -Dorg="$APIGEE_X_ORG" -Denv="$APIGEE_X_ENV" \
-Dtoken="$TOKEN" -Dapi.northbound.domain="$APIGEE_X_HOSTNAME" \
-f test/integration/pom.xml

# Destroy test API Product, Apps
mvn apigee-config:apps apigee-config:apiproducts -Pgoogleapi \
-Dorg="$APIGEE_X_ORG" -Denv="$APIGEE_X_ENV" \
-Dtoken="$TOKEN" -Dapi.northbound.domain="$APIGEE_X_HOSTNAME" -Dapigee.config.options="delete" \
-f test/integration/pom.xml

# Apigee Edge

# Deploy the sharedflow
mvn clean install -Papigeeapi -Dorg="$APIGEE_ORG" -Denv="$APIGEE_ENV" \
-Dusername="$APIGEE_USER" -Dpassword="$APIGEE_PASS"

# Deploy the proxy to test the shareflow
mvn install -Papigeeapi -Dorg="$APIGEE_ORG" -Denv="$APIGEE_ENV" \
-Dusername="$APIGEE_USER" -Dpassword="$APIGEE_PASS" -f test/integration/pom.xml

# Destroy test API Product, Apps
mvn apigee-config:apps apigee-config:apiproducts -Papigeeapi \
-Dorg="$APIGEE_ORG" -Denv="$APIGEE_ENV" \
-Dusername="$APIGEE_USER" -Dpassword="$APIGEE_PASS" -Dapigee.config.options="delete" \
-f test/integration/pom.xml
