# Copyright 2020 Google LLC
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

FROM jenkins4eval/jenkinsfile-runner:1.0-beta-25

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash -
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  maven=3.6.1* \
  nodejs=14.* \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app/jenkins
RUN jar -cvf jenkins.war ./*
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN java -jar /app/bin/jenkins-plugin-manager.jar --war /app/jenkins/jenkins.war --plugin-file /usr/share/jenkins/ref/plugins.txt
RUN rm /app/jenkins/jenkins.war

ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/jenkins.yaml
COPY jenkins.yml $CASC_JENKINS_CONFIG

ENV APIGEE_HOSTURL=https://api.enterprise.apigee.com
