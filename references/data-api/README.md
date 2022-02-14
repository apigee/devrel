# Apigee on top of Data APIs

## Configure the SA to be used by Apigee

```sh
SA=bq-reader
SA_EMAIL="$SA@$PROJECT_ID.iam.gserviceaccount.com"
gcloud iam service-accounts create "$A" --project="$PROJECT_ID" --display-name="BQ data reader"
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA_EMAIL" --role="roles/bigquery.dataViewer" --quiet
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA_EMAIL" --role="roles/bigquery.user" --quiet
```

## Template the proxy

```
PROJECT_ID='my-project'
export BASE_PATH='/london/bikes/v1'
export DATA_SET='bigquery-public-data.london_bicycles.cycle_hire'

export PROXY_NAME="$( tr '/' '-' <<< ${BASE_PATH:1})"

mkdir "./$PROXY_NAME/"
cp -r template/ "./$PROXY_NAME/"

find ./$PROXY_NAME -name '*.xml' -print0 |
while IFS= read -r -d '' file; do
    echo "replacing variables in $file"
    envsubst < "$file" > "$file.out"
    mv "$file.out" "$file"
done

mv "./$PROXY_NAME/apiproxy/proxy.xml" "./$PROXY_NAME/apiproxy/$PROXY_NAME.xml"
```

## Deploy the proxy

```sh
APIGEE_TOKEN=$(gcloud auth print-access-token);
APIGEE_X_ORG="$PROJECT_ID"
APIGEE_X_ENV="test1" # set this to the env you want to deploy to
sackmesser deploy -o $APIGEE_X_ORG -e $APIGEE_X_ENV -d "./$PROXY_NAME" -t "$APIGEE_TOKEN" --deployment-sa "$SA_EMAIL"
```

## Test the proxy

```
APIGEE_X_HOSTNAME='my-proxy-hostname'

curl "https://$APIGEE_X_HOSTNAME/london/bikes/v1" -v
```