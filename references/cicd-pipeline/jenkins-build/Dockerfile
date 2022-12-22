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


FROM jenkins/jenkins:2.346-alpine

USER root
RUN apk update && apk add --no-cache git maven nodejs npm

# Reduce log (note: -ntp requires maven 3.6.1+)
RUN mv /usr/bin/mvn /usr/bin/_mvn &&\
  printf '#!/bin/bash\n/usr/bin/_mvn -ntp "$@"' > /usr/bin/mvn && \
  chmod +x /usr/bin/mvn

USER jenkins

COPY --chown=jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

COPY --chown=jenkins jenkins.yml /var/jenkins_home/casc_configs/jenkins.yaml
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml

ENV JENKINS_ADMIN_PASS=admin
ENV APIGEE_HOSTURL=https://api.enterprise.apigee.com
