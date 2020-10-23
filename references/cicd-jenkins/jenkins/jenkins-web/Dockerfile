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

FROM jenkins/jenkins:2.249.1-alpine

USER root
RUN apk update && apk add --no-cache git=2.26.2-r0 maven=3.6.3-r0 nodejs=12.18.4-r0 npm=12.18.4-r0
USER jenkins

COPY --chown=jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
COPY --chown=jenkins jenkins-web/additional-plugins.txt /usr/share/jenkins/ref/additional-plugins.txt
RUN cat /usr/share/jenkins/ref/additional-plugins.txt >> /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt

COPY --chown=jenkins jenkins.yml /var/jenkins_home/casc_configs/jenkins.yaml
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Dhudson.model.DirectoryBrowserSupport.CSP=\"sandbox allow-same-origin allow-scripts; default-src 'self'; script-src * 'unsafe-inline' ; img-src *; style-src * 'unsafe-inline'; font-src *\" ${JAVA_OPTS}"
ENV JENKINS_ADMIN_PASS=admin
ENV APIGEE_HOSTURL=https://api.enterprise.apigee.com
