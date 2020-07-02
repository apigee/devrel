FROM jenkins/jenkins:2.239-alpine

USER root
RUN apk update && apk add --no-cache git nodejs npm maven
USER jenkins

COPY classic/plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt

COPY jenkins.yml /var/jenkins_home/casc_configs/jenkins.yaml
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false ${JAVA_OPTS}"
ENV JENKINS_ADMIN_PASS=admin
