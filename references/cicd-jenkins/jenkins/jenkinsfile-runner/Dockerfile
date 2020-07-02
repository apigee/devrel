FROM jenkins4eval/jenkinsfile-runner:1.0-beta-12
RUN apt update && apt install -y npm maven nodejs
RUN cd /app/jenkins && jar -cvf jenkins.war *
COPY jenkinsfile-runner/plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN java -jar /app/bin/jenkins-plugin-manager.jar --war /app/jenkins/jenkins.war --plugin-file /usr/share/jenkins/ref/plugins.txt
RUN rm /app/jenkins/jenkins.war

ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/jenkins.yaml
COPY jenkins.yml $CASC_JENKINS_CONFIG
