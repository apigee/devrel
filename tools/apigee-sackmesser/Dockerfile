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

FROM maven:3.6.3-slim

RUN apt-get update && \
  apt-get install git=* libxml2-utils=* jq=* unzip=* --no-install-recommends -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY tools/apigee-sackmesser /opt/devrel/tools/apigee-sackmesser
COPY references/kvm-admin-api /opt/devrel/references/kvm-admin-api

RUN mkdir /opt/apigee

RUN groupadd -r apigee && useradd --no-log-init -m -r -g apigee apigee && \
  chown -R apigee /opt/devrel && chown -R apigee /opt/apigee

USER apigee

# Pre-warm maven cache for deploy
WORKDIR /opt/devrel/tools/apigee-sackmesser
RUN mvn clean -f ./cmd/deploy/pom-hybrid.xml && \
  mvn clean -f ./cmd/deploy/pom-edge.xml

ENV PATH="/opt/devrel/tools/apigee-sackmesser/bin:${PATH}"

WORKDIR /opt/apigee

ENTRYPOINT [ "sackmesser" ]
