# Jenkins Example Setup

## Classic Jenkins

```bash
docker build -f classic/Dockerfile -t apigee-cicd/jenkins .

docker run \
  -p 8080:8080 \
  -p 5000:5000 \
  -e APIGEE_USER \
  -e APIGEE_PASS \
  -e APIGEE_ORG \
  -e JENKINS_ADMIN_PASS=password \
  apigee-cicd/jenkins
```

## Jenkinsfile-Runner

```bash
docker build -f jenkinsfile-runner/Dockerfile -t apigee-cicd/jenkinsfile-runner .

docker run \
  -v ${PWD}/airports-cicd-v1:/workspace \
  -e APIGEE_USER \
  -e APIGEE_PASS \
  -e APIGEE_ORG \
  -e GIT_BRANCH=travis \
  -e AUTHOR_EMAIL="cicd@apigee.google.com" \
  -it apigee-cicd/jenkinsfile-runner
```