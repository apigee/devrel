#!/bin/bash
GCLOUD_APIGEE_TOKEN=$1
APIGEE_ORG=$2
APIGEE_ENV=$3
GPROJECT_APIGEE=$4
GPROJECT_GCP=$5
APIGEE_URL=$6
RAND=${7}
WORKLOAD_LEVEL=${8}
DEPLOYMENT=${9}

GCP_SVC_ACCOUNT_EMAIL=$(cat ../load-generator-key.json | jq -r .client_email)
gcloud auth activate-service-account \
        $GCP_SVC_ACCOUNT_EMAIL \
        --key-file=../load-generator-key.json --project=$GPROJECT_GCP
folder=$PWD
if [ $DEPLOYMENT == "all" ] || [ $DEPLOYMENT == "backends" ]; then
        cd $folder
        gcloud config set project $GPROJECT_GCP
        gcloud app create --region europe-west2
        echo "---->DEPLOYING BACKENDS<-------"
        cd backend/services
        gcloud config list
        cd default
        gcloud app deploy app.yaml --project $GPROJECT_GCP --promote --quiet
        cd ../catalog
        gcloud app deploy app.yaml --project $GPROJECT_GCP --promote --quiet
        cd ../checkout
        gcloud app deploy app.yaml --project $GPROJECT_GCP --promote --quiet
        cd ../loyalty
        gcloud app deploy app.yaml --project $GPROJECT_GCP --promote --quiet
        cd ../recommendation
        gcloud app deploy app.yaml --project $GPROJECT_GCP --promote --quiet
        cd ../users
        gcloud app deploy app.yaml --project $GPROJECT_GCP --promote --quiet
fi
if [ $DEPLOYMENT == "all" ] || [ $DEPLOYMENT == "apigee" ]; then
        #Deploy target servers
        cd $folder
        gcloud config set project $GPROJECT_APIGEE
        echo "---->DEPLOYING Target Servers<-------"
        cd config
        cp shared-pom.xml.template shared-pom.xml
        cp edge.json.template edge.json
        sed -i "s/<environment>/$APIGEE_ENV/g" shared-pom.xml
        sed -i "s/<environment>/$APIGEE_ENV/g" edge.json
        cd targetservers
        cp shared-pom.xml.template shared-pom.xml
        sed -i "s/<environment>/$APIGEE_ENV/g" shared-pom.xml
        cp edge.json.template edge.json
        DOMAIN_SERVICE=$(gcloud app services browse catalog --no-launch-browser --format json | jq -r .[].url | cut -d'-' -f 2,3,4,5,6,7,8,9,10,11,12,13,14)
        sed -i "s/<domain>/-$DOMAIN_SERVICE/g" edge.json
        sed -i "s/<environment>/$APIGEE_ENV/g" edge.json
        mvn install -P$APIGEE_ENV -Dorg=$APIGEE_ORG -Denv=$APIGEE_ENV -Dbearer=$GCLOUD_APIGEE_TOKEN -Dapigee.config.options=create

        #Deploying proxies
        echo "---->DEPLOYING PROXIES<-------"
        cd $folder
        cd proxies
        cp shared-pom.xml.template shared-pom.xml
        sed -i "s/<environment>/$APIGEE_ENV/g" shared-pom.xml
        cd Load-Generator-Catalog
        sed -i "s/<environment>/$APIGEE_ENV/g" shared-pom.xml
        cp config.json.template config.json
        sed -i "s/<environment>/$APIGEE_ENV/g" config.json
        sed -i "s/<gproject>/$GPROJECT_APIGEE/g" config.json
        mvn install -P$APIGEE_ENV -Dorg=$APIGEE_ORG -Denv=$APIGEE_ENV -Dbearer=$GCLOUD_APIGEE_TOKEN
        cd ../Load-Generator-Checkout
        cp config.json.template config.json
        sed -i "s/<environment>/$APIGEE_ENV/g" config.json
        sed -i "s/<gproject>/$GPROJECT_APIGEE/g" config.json
        mvn install -P$APIGEE_ENV -Dorg=$APIGEE_ORG -Denv=$APIGEE_ENV -Dbearer=$GCLOUD_APIGEE_TOKEN
        cd ../Load-Generator-Loyalty
        cp config.json.template config.json
        sed -i "s/<environment>/$APIGEE_ENV/g" config.json
        sed -i "s/<gproject>/$GPROJECT_APIGEE/g" config.json
        mvn install -P$APIGEE_ENV -Dorg=$APIGEE_ORG -Denv=$APIGEE_ENV -Dbearer=$GCLOUD_APIGEE_TOKEN
        cd ../Load-Generator-Recommendation
        cp config.json.template config.json
        sed -i "s/<environment>/$APIGEE_ENV/g" config.json
        sed -i "s/<gproject>/$GPROJECT_APIGEE/g" config.json
        mvn install -P$APIGEE_ENV -Dorg=$APIGEE_ORG -Denv=$APIGEE_ENV -Dbearer=$GCLOUD_APIGEE_TOKEN
        cd ../Load-Generator-User
        cp config.json.template config.json
        sed -i "s/<environment>/$APIGEE_ENV/g" config.json
        sed -i "s/<gproject>/$GPROJECT_APIGEE/g" config.json
        mvn install -P$APIGEE_ENV -Dorg=$APIGEE_ORG -Denv=$APIGEE_ENV -Dbearer=$GCLOUD_APIGEE_TOKEN


        #Deploy products
        echo "---->DEPLOYING PRODUCTS, DEVELOPERS AND APPS<-------"
        cd $folder
        cd config
        sed -i "s/<environment>/$APIGEE_ENV/g" edge.json
        mvn install -P$APIGEE_ENV -Dorg=$APIGEE_ORG -Denv=$APIGEE_ENV -Dbearer=$GCLOUD_APIGEE_TOKEN -Dapigee.config.options=create

        #enabling distributed tracing
        curl -H "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" -H "Content-Type: application/json" https://apigee.googleapis.com/v1/organizations/$APIGEE_ORG/environments/$APIGEE_ENV/traceConfig -X PATCH -d '{"exporter": "CLOUD_TRACE","endpoint": "$GPROJECT_APIGEE","samplingConfig": {"sampler": "PROBABILITY","samplingRate": 0.5}}'
fi
if [ $DEPLOYMENT == "all" ] || [ $DEPLOYMENT == "gcp" ]; then
        #Building docker image
        cd $folder
        cd consumers
        cp Dockerfile_template Dockerfile
        sed -i "s/GCP_TOKEN/$GCLOUD_APIGEE_TOKEN/g" Dockerfile
        sed -i "s/APIGEE_ORG/$APIGEE_ORG/g" Dockerfile
        sed -i "s/APIGEE_ENV/$APIGEE_ENV/g" Dockerfile
        sed -i "s/HOST/$APIGEE_URL/g" Dockerfile
        sed -i "s/WORKLOAD_LEVEL/$WORKLOAD_LEVEL/g" Dockerfile

        # Deploying Locust instances
        gcloud config set project $GPROJECT_GCP
        gcloud services enable cloudbuild.googleapis.com compute.googleapis.com storage.googleapis.com storage-api.googleapis.com   
        gcloud builds submit --tag gcr.io/$GPROJECT_GCP/load-test
        gcloud compute addresses create $(echo "v2-1-load-locust-ip-"$RAND) --region europe-west2
        ADDR=$(gcloud compute addresses describe v2-1-load-locust-ip-$(echo $RAND) --region europe-west2 --format json | jq -r '.address')
        gcloud compute instances create-with-container $(echo "v2-1-load-locust-"$RAND) --machine-type=e2-standard-2 --container-image gcr.io/$GPROJECT_GCP/load-test --address $ADDR --zone europe-west2-b 
fi





