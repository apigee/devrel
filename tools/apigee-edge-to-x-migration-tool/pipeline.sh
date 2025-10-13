#!/bin/bash
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Exit immediately if a command exits with a non-zero status
set -e

# Create a temporary environment file
TEMP_ENV=".env"
echo "Creating temporary environment file..."
cat <<EOL >$TEMP_ENV
install_modules=1
source_gateway_type="apigee_edge"
destination_gateway_type="apigee_x"
source_gateway_base_url="https://api.enterprise.apigee.com/v1/organizations/"
destination_gateway_base_url="https://apigee.googleapis.com/v1/organizations/"

source_gateway_org=$APIGEE_ORG
source_gateway_username=$APIGEE_USER
source_gateway_password=$APIGEE_PASS

destination_gateway_org=$APIGEE_X_ORG
destination_gateway_service_account="eyJvcmdhbml6YXRpb24iOiJ0ZXN0In0="

apigee_environment_map='{$APIGEE_ENV:$APIGEE_X_ENV}'
EOL

# Ensure the temporary file is not tracked by git
echo "$TEMP_ENV" >>.gitignore

# Source the temporary environment file
echo "Sourcing temporary environment file..."
source $TEMP_ENV

# Trigger the tool-setup.sh
echo "Running tool-setup.sh..."
chmod +x ./tool-setup.sh
bash ./tool-setup.sh &

sleep 30
# Clean up: Remove the temporary environment file after execution
echo "Cleaning up temporary files..."
rm -f $TEMP_ENV

echo "Pipeline execution completed successfully."
