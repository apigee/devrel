# Jenkins Setup

## Jenkins Build

To allow for the Jenkins container to use Docker-container based builds, we need build a new Docker image first:

```js
docker build -t apigee/jenkins .
```

## Run Jenkins with a mounted home folder

Although the volume mount for the jenkins_home directory is optional, it is highly encouraged to avoid having to do the manual jenkins configuration multiple times.

```sh
sudo mkdir /var/jenkins_home
sudo chmod 777 /var/jenkins_home

docker run -d -it -p 8080:8080 -p 50000:50000 --name jenkins \
    --group-add $(stat -c '%g' /var/run/docker.sock) \
    -v /var/jenkins_home:/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --restart unless-stopped \
    apigee/jenkins:latest
```

## Manual Jenkins Init

To obtain an API key for configuring Jenkins via the provided API, follow these steps:

1.  Once the Jenkins UI has loaded and prompts you for the admin key, supply the inital admin key which you can obtain from running `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`
1.  Click the button to install the default plugins
1.  Create an admin user with the username `admin` (Password and Email can be arbitrary)
1.  Navigate to `localhost:8080/me/configure`, create an API token, and store it in an `JENKINS_KEY` variable: `export JENKINS_KEY=<key goes here>`


### Install the reporting plugins

```sh
curl -u admin:$JENKINS_KEY -X POST -d '<jenkins><install plugin="htmlpublisher@1.22" /></jenkins>' --header 'Content-Type: text/xml' "http://localhost:8080/pluginManager/installNecessaryPlugins"
curl -u admin:$JENKINS_KEY -X POST -d '<jenkins><install plugin="cucumber-reports@5.0.2" /></jenkins>' --header 'Content-Type: text/xml' "http://localhost:8080/pluginManager/installNecessaryPlugins"
```

## Setup Jenkins Credentials

This assumes you have the environment variables `APIGEE_USERNAME` and `APIGEE_PASSWORD` populated with your Apigee credentials.

```sh
curl -X POST \
    -u admin:$JENKINS_KEY \
    -H 'content-type:application/xml' \
    -d "
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>apigee</id>
  <description>Apigee CICD Credentials</description>
  <username>$APIGEE_USERNAME</username>
  <password>$APIGEE_PASSWORD</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
" "http://localhost:8080/credentials/store/system/domain/_/createCredentials"
```

## Create a Multibrach Jenkins Job

Use the UI to configure the Jenkins Job for multibranch pipelines:

1.  Point to the SCM Jenkinsfile
1.  Set the Git repo accordingly
1.  Set the build trigger / polling frequency

The `config.xml` contains a readily configured pipeline which may or may not be applicable given the detached versioning of the jenkins plugins:

```sh
curl -X POST -u admin:$JENKINS_KEY --header "Content-Type: application/xml" -d '@config.xml' http://localhost:8080/createItem?name=CurrencyAPI
```
