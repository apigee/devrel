pipeline {

    agent any

    environment {
        APIGEE_CREDS = credentials('apigee')
        // Mutliple options for setting the Apigee target org:
        // 1. As a jenkins global property at ${JENKINS_URL}/configure if you don't have access to edit this file
        // 2. As a environment variable for all branches (see below)
        // 3. As a branch specific environment variable in the first pipeline stage
        // APIGEE_ORG = 'apigee-org-name'
    }

    stages {
        stage('Set Apigee Env and Proxy Suffix') {
          steps {
            script{
              // Main branch for Apigee test environment
              if (env.GIT_BRANCH == "main") {
                  env.APIGEE_DEPLOYMENT_SUFFIX = ""
                  env.APIGEE_ENV = "test"
                  // env.APIGEE_ORG = 'apigee-org-name'
              // Prod branch for Apigee prod environment
              } else if (env.GIT_BRANCH == "prod") {
                  env.APIGEE_DEPLOYMENT_SUFFIX = ""
                  env.APIGEE_ENV = "prod"
                  // env.APIGEE_ORG = 'apigee-org-name'
              // All other branches are deployed as separate proxies with suffix in the test environment
              } else {
                  env.APIGEE_DEPLOYMENT_SUFFIX = env.GIT_BRANCH ? "-" + env.GIT_BRANCH.replaceAll("\\W", "-") : "-devrel-jenkins"
                  env.APIGEE_ENV = "test"
                  // env.APIGEE_ORG = 'apigee-org-name'
              }
              println "Proxy Deployment Suffix: " + env.APIGEE_DEPLOYMENT_SUFFIX
            }
          }
        }

        stage('Install dependencies') {
          steps {
            sh "npm install --silent --no-fund"
          }
        }

        stage('Static Code Analysis') {
          steps {
            sh "./node_modules/eslint/bin/eslint.js -c ./.eslintrc-jsc.yml --format html . > eslint-out.html"

            publishHTML(target: [
              allowMissing: false,
              alwaysLinkToLastBuild: false,
              keepAll: false,
              reportDir: ".",
              reportFiles: 'eslint-out.html',
              reportName: 'ESLint Report'
            ]);

            sh "rm eslint-out.html"

            sh "npm run apigeelint > apigeelint-out.html"

            publishHTML(target: [
              allowMissing: false,
              alwaysLinkToLastBuild: false,
              keepAll: false,
              reportDir: ".",
              reportFiles: 'apigeelint-out.html',
              reportName: 'Apigeelint Report'
            ]);

            sh "rm apigeelint-out.html"
          }
        }

        stage('Unit Test') {
          steps {
            sh "./node_modules/nyc/bin/nyc.js --reporter=html --reporter=text ./node_modules/mocha/bin/_mocha ./test/unit"

            publishHTML(target: [
              allowMissing: false,
              alwaysLinkToLastBuild: false,
              keepAll: false,
              reportDir: "coverage",
              reportFiles: 'index.html',
              reportName: 'Unit Test Report'
            ])
          }
        }

        stage('Env Config') {
          steps {
            script {
              if (!env.AUTHOR_EMAIL) {
                env.AUTHOR_EMAIL = sh (
                  script: 'git --no-pager show -s --format=\'%ae\'',
                  returnStdout: true
                ).trim()
              }
            }

            sh """
              mvn clean install \
                -P"apigeeapi" \
                -Dpassword="${APIGEE_CREDS_PSW}" \
                -Denv="${env.APIGEE_ENV}" \
                -Dusername="${APIGEE_CREDS_USR}" \
                -Dorg="${env.APIGEE_ORG}" \
                -Ddeployment.suffix="${env.APIGEE_DEPLOYMENT_SUFFIX}" \
                -Ddeployment.description="Jenkins Build: ${env.BUILD_TAG} Author: ${env.AUTHOR_EMAIL}"
            """
          }
        }

        stage('Functional Test') {
          steps {
            sh "node ./node_modules/.bin/cucumber-js ./target/test/integration --format json:./target/reports.json"
          }
        }
    }

    post {
      always {
        cucumber reportTitle: 'Apickli test report',
              fileIncludePattern: '**/reports.json',
              jsonReportDirectory: "target",
              sortingMethod: 'ALPHABETICAL',
              trendsLimit: 10
      }
    }
}