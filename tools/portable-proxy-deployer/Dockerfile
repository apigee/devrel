FROM maven:3.6.3-jdk-11

RUN apt-get update && apt-get install libxml-xpath-perl -y

RUN mkdir /opt/apigee

WORKDIR /opt/apigee
COPY pom.xml ./pom.xml

# Pre-warm maven cache
RUN mvn clean -Papigeeapi
RUN mvn clean -Pgoogleapi

COPY deploy.sh ./deploy.sh

ENTRYPOINT [ "./deploy.sh" ]
