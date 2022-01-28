FROM  gcr.io/apigee-microgateway/edgemicro:latest

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


# Install some basic troubleshooting utilities
USER root
RUN apt-get update -y && \
    apt-get install -y curl dnsutils iputils-ping net-tools
RUN apt-get install -y --reinstall procps
USER apigee

# Arbitrarily sleep 10 secodns to give enough time for the envoy side-car to come up
ENTRYPOINT ["bash", "-c", "sleep 10; /opt/apigee/entrypoint.sh"]