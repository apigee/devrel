FROM jenkins4eval/jenkinsfile-runner:1.0-beta-12
RUN apt update && apt install -y maven nodejs npm
RUN cd /app/jenkins && jar -cvf jenkins.war *
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN java -jar /app/bin/jenkins-plugin-manager.jar --war /app/jenkins/jenkins.war --plugin-file /usr/share/jenkins/ref/plugins.txt
RUN rm /app/jenkins/jenkins.war

ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/jenkins.yaml
COPY jenkins.yml $CASC_JENKINS_CONFIG

ENV APIGEE_HOSTURL=https://api.enterprise.apigee.com
