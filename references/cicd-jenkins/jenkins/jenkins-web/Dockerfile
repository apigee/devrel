FROM jenkins/jenkins:2.239-alpine

USER root
RUN apk update && apk add --no-cache git maven nodejs npm
USER jenkins

COPY --chown=jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
COPY --chown=jenkins jenkins-web/additional-plugins.txt /usr/share/jenkins/ref/additional-plugins.txt
RUN cat /usr/share/jenkins/ref/additional-plugins.txt >> /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt

COPY --chown=jenkins jenkins.yml /var/jenkins_home/casc_configs/jenkins.yaml
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false ${JAVA_OPTS}"
ENV JENKINS_ADMIN_PASS=admin
ENV APIGEE_HOSTURL=https://api.enterprise.apigee.com
