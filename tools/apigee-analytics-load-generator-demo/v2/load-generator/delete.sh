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

gcloud config set project $GPROJECT_GCP
GCP_SVC_ACCOUNT_EMAIL=$(cat ../load-generator-key.json | jq -r .client_email)
gcloud auth activate-service-account \
        $GCP_SVC_ACCOUNT_EMAIL \
        --key-file=../load-generator-key.json --project=$GPROJECT_GCP

folder=$PWD
if [ $DEPLOYMENT == "all" ] || [ $DEPLOYMENT == "gcp" ]; then
    #Deleting GCP Stuff
    echo "----------Deleting v2-load-locust instances"
    gcloud compute instances delete $(echo "v2-1-load-locust-"$RAND) --zone europe-west2-b --quiet &
    gcloud compute addresses delete $(echo "v2-1-load-locust-ip-"$RAND) --region europe-west2 --quiet
fi 
if [ $DEPLOYMENT == "all" ] || [ $DEPLOYMENT == "backends" ]; then
    echo "----------Deleting backends------------"
    gcloud app services delete catalog users recommendation loyalty checkout --quiet
    versions=$(gcloud app versions list --format json | jq -r ".[].id")
    for version in $versions; do
        gcloud app versions delete $version --quiet
    done

fi
if [ $DEPLOYMENT == "all" ] || [ $DEPLOYMENT == "apigee" ]; then
    # DELETING APIGEE's STUFF
    gcloud config set project $GPROJECT_APIGEE
    export APIGEE_MNGMT_URL="https://apigee.googleapis.com/v1/organizations/$APIGEE_ORG"

    arr=("hugh@startkaleo.com" "grant@enterprise.com" "petsell@wrong.com" "tomjones@enterprise.com" "joew@bringiton.com" "acop@enterprise.com" "barbg@enterprise.com" "dandee@enterprise.com" "freds@bringiton.com")

    for dev in ${arr[@]}; do
        echo "Developer: "$dev
        DEVS_APPS=$(curl --silent -X GET --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/developers/$dev/apps") > /dev/null
        echo "----------Deleting apps"
        for app in $(echo $DEVS_APPS | jq -r .app[0].appId); do
            echo "Deleting app: $app"
            curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/developers/$dev/apps/${app}" > /dev/null
        done
        echo "Deleting developer: $dev"
        curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/developers/$dev" > /dev/null
    done

    declare -a prods=("Load-Generator-Product-Store" "Load-Generator-Product-Shopping" "Load-Generator-Product-Catalog" "Load-Generator-Product-Consumer" "Load-Generator-Product-Admin")

    echo "----------Deleting products"
    for product in ${prods[@]}; do  
        echo "Deleting Product: $product"
        curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/apiproducts/${product}"  > /dev/null
    done


    echo "----------Deleting deployments"
    revisions=$(curl $APIGEE_MNGMT_URL/apis/Load-Generator-Catalog/revisions --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN")
    for row in $(echo "${revisions}" | jq -r '.[]'); do
        curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/environments/$APIGEE_ENV/apis/Load-Generator-Catalog/revisions/$row/deployments"
    done
    revisions=$(curl $APIGEE_MNGMT_URL/apis/Load-Generator-Users/revisions --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN")
    for row in $(echo "${revisions}" | jq -r '.[]'); do
        curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/environments/$APIGEE_ENV/apis/Load-Generator-Users/revisions/$row/deployments"
    done
    revisions=$(curl $APIGEE_MNGMT_URL/apis/Load-Generator-Recommendation/revisions --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN")
    for row in $(echo "${revisions}" | jq -r '.[]'); do
        curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/environments/$APIGEE_ENV/apis/Load-Generator-Recommendation/revisions/$row/deployments"
    done
    revisions=$(curl $APIGEE_MNGMT_URL/apis/Load-Generator-Loyalty/revisions --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN")
    for row in $(echo "${revisions}" | jq -r '.[]'); do
        curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/environments/$APIGEE_ENV/apis/Load-Generator-Loyalty/revisions/$row/deployments"
    done
    revisions=$(curl $APIGEE_MNGMT_URL/apis/Load-Generator-Checkout/revisions --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN")
    for row in $(echo "${revisions}" | jq -r '.[]'); do
        curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/environments/$APIGEE_ENV/apis/Load-Generator-Checkout/revisions/$row/deployments"
    done
    echo "----------Deleting revision proxies"
    revisions=$(curl $APIGEE_MNGMT_URL/apis/Load-Generator-Catalog/revisions --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN")
    for row in $(echo "${revisions}" | jq -r '.[]'); do
        curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/apis/Load-Generator-Catalog/revisions/$row"
    done
    revisions=$(curl $APIGEE_MNGMT_URL/apis/Load-Generator-Recommendation/revisions --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN")
    for row in $(echo "${revisions}" | jq -r '.[]'); do
        curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/apis/Load-Generator-Recommendation/revisions/$row"
    done
    revisions=$(curl $APIGEE_MNGMT_URL/apis/Load-Generator-Users/revisions --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN")
    for row in $(echo "${revisions}" | jq -r '.[]'); do
        curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/apis/Load-Generator-Users/revisions/$row"
    done
    revisions=$(curl $APIGEE_MNGMT_URL/apis/Load-Generator-Loyalty/revisions --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN")
    for row in $(echo "${revisions}" | jq -r '.[]'); do
        curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/apis/Load-Generator-Loyalty/revisions/$row"
    done
    revisions=$(curl $APIGEE_MNGMT_URL/apis/Load-Generator-Checkout/revisions --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN")
    for row in $(echo "${revisions}" | jq -r '.[]'); do
        curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/apis/Load-Generator-Checkout/revisions/$row"
    done


    echo "----------Deleting proxies"
    curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/apis/Load-Generator-Catalog"
    curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/apis/Load-Generator-Users"
    curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/apis/Load-Generator-Recommendation"
    curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/apis/Load-Generator-Loyalty"
    curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/apis/Load-Generator-Checkout"

    echo "----------Deleting Target Servers"
    curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/environments/$APIGEE_ENV/targetservers/Load-Generator-Catalog-Target"
    curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/environments/$APIGEE_ENV/targetservers/Load-Generator-Checkout-Target"
    curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/environments/$APIGEE_ENV/targetservers/Load-Generator-Loyalty-Target"
    curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/environments/$APIGEE_ENV/targetservers/Load-Generator-Recommendation-Target"
    curl --silent -X DELETE --header "Authorization: Bearer $GCLOUD_APIGEE_TOKEN" "$APIGEE_MNGMT_URL/environments/$APIGEE_ENV/targetservers/Load-Generator-Users-Target"
fi