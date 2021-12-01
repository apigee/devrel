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

FROM jenkins4eval/jenkinsfile-runner:1.0-beta-29 as filerunner

FROM jenkins/jenkins:2.315-alpine

USER root
RUN apk update && apk add --no-cache git maven nodejs npm
USER jenkins

COPY --from=filerunner --chown=jenkins /app /app
WORKDIR /app/jenkins
COPY --chown=jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt

ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/jenkins.yaml
COPY jenkins.yml $CASC_JENKINS_CONFIG

ENV APIGEE_HOSTURL=https://api.enterprise.apigee.com

ENTRYPOINT ["/app/bin/jenkinsfile-runner", "-w", "/usr/share/jenkins/", "-p", "/usr/share/jenkins/ref/plugins", "-f"]

CMD ["/workspace/Jenkinsfile"]
