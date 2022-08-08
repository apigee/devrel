#!/bin/bash

# Copyright 2022 Google LLC
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

chmod 644 "$CLI_HOME"/config.yaml

sleep 5

if [[ -z $PIPELINE_TEST ]]; then

  nohup docker run \
  -v $CLI_HOME/config.yaml:/config.yaml \
  -p 5000:5000 google/apigee-envoy-adapter:v2.0.5 &

else
  echo "Creating Dockerfile to copy the config files for apigee-envoy-adapter"

  cat << EOF >  "$ENVOY_HOME/Dockerfile-aekitctl"
FROM google/apigee-envoy-adapter:v2.0.5
COPY ./apigee-remote-service-cli/config.yaml /config.yaml
EOF

  docker build -f "$ENVOY_HOME/Dockerfile-aekitctl" \
  -t apigee/devrel-apigee-envoy-adapter:latest "$ENVOY_HOME"

  rm  "$ENVOY_HOME/Dockerfile-aekitctl"

  nohup docker run \
  -p 5000:5000 apigee/devrel-apigee-envoy-adapter:latest &

fi

echo "END of envoy-adapter....."

docker ps -a

sleep 5

mkdir $ENVOY_CONFIGS_HOME/logs

chmod 777 $ENVOY_CONFIGS_HOME/logs

cd $ENVOY_CONFIGS_HOME
sed -i "s/localhost/127.0.0.1/g" $ENVOY_CONFIGS_HOME/envoy-config.yaml

chmod 644 $ENVOY_CONFIGS_HOME/envoy-config.yaml

if [[ -z $PIPELINE_TEST ]]; then

    nohup docker run --net=host -v $ENVOY_CONFIGS_HOME/logs:/tmp/logs \
    -v $ENVOY_CONFIGS_HOME/envoy-config.yaml:/etc/envoy/envoy.yaml \
    -p 8080:8080 \
    --rm envoyproxy/envoy:v1.21-latest --log-path /tmp/logs/custom.log \
    -c /etc/envoy/envoy.yaml --log-level debug &

else
  echo "Creating Dockerfile to copy the config files for envoy"
  cat << EOF >  "$ENVOY_HOME/Dockerfile-aekitctl"
FROM envoyproxy/envoy:v1.21-latest
RUN apt-get update
RUN apt-get -y install curl
COPY ./apigee-remote-service-cli/envoy-configs-and-samples/envoy-config.yaml /etc/envoy/envoy.yaml
EOF

  docker build -f "$ENVOY_HOME/Dockerfile-aekitctl" \
  -t apigee/devrel-envoyproxy:latest "$ENVOY_HOME"

  rm  "$ENVOY_HOME/Dockerfile-aekitctl"

    nohup docker run --net=host \
    -p 8080:8080 \
    --rm apigee/devrel-envoyproxy:latest \
    -c /etc/envoy/envoy.yaml \
    --log-path /tmp/custom.log \
    --log-level debug &

fi

sleep 5

docker ps -a
