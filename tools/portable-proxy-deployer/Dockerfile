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

RUN groupadd -r apigee && useradd --no-log-init -m -r -g apigee apigee

RUN apt-get update && \
  apt-get install git=* libxml2-utils=* --no-install-recommends -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*


RUN mkdir /opt/apigee && chown -R apigee /opt/apigee

USER apigee

WORKDIR /opt/apigee

COPY pom-edge.xml ./pom-edge.xml
COPY pom-hybrid.xml ./pom-hybrid.xml

# Pre-warm maven cache
RUN mvn clean -f pom-hybrid.xml
RUN mvn clean -f pom-edge.xml

COPY deploy.sh ./deploy.sh

ENTRYPOINT [ "./deploy.sh" ]
