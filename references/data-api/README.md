# Apigee on top of Data APIs

This reference provides a basic proxy generator that allows you to build an
API facade on a data platform. (In this example we are using BigQuery as the
data platform but the same principles could be applied to other products.)

The API proxy provides the following functionality to facilitate and govern
data consumption via APIs:

* Response Cache
* Quota (Default or API Product)
* Return Size Limit (with enforced max)
* Pagination
* Fields Selection
* Injection Protection (Using Regex Matching)
* CORS headers

## Getting Started

### Configure the SA to be used by Apigee

```sh
SA=bq-reader
SA_EMAIL="$SA@$APIGEE_X_ORG.iam.gserviceaccount.com"
BQ_PROJECT_ID='my-bq-project'

gcloud iam service-accounts create "$SA" --project="$APIGEE_X_ORG" --display-name="BQ data reader"
gcloud projects add-iam-policy-binding "$BQ_PROJECT_ID" --member="serviceAccount:$SA_EMAIL" --role="roles/bigquery.dataViewer" --quiet
gcloud projects add-iam-policy-binding "$BQ_PROJECT_ID" --member="serviceAccount:$SA_EMAIL" --role="roles/bigquery.user" --quiet
```

### Template the proxy

```sh
export BQ_PROJECT_ID='my-bq-project'
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

### Deploy the proxy

```sh
APIGEE_TOKEN=$(gcloud auth print-access-token);
APIGEE_X_ORG="$PROJECT_ID"
APIGEE_X_ENV="test1" # set this to the env you want to deploy to
sackmesser deploy -o $APIGEE_X_ORG -e $APIGEE_X_ENV -d "./$PROXY_NAME" -t "$APIGEE_TOKEN" --deployment-sa "$SA_EMAIL"
```

### Try it out

```sh
APIGEE_X_HOSTNAME='my-proxy-hostname'
```

Basic API request

```sh
curl "https://$APIGEE_X_HOSTNAME/london/bikes/v1" -v
```

Using query params

```sh
curl "https://$APIGEE_X_HOSTNAME/london/bikes/v1?limit=3&fields=start_station_name,end_station_name" | jq
```

Triggering the quota limit for unauthenticated users:

```sh
curl "https://$APIGEE_X_HOSTNAME/london/bikes/v1?try=[1-10]" -I
```

(Optional) Create an API product with a higher quota and an app for it. Use the app's
key in an `apikey` query parameter in your request:

```sh
APIKEY='key-goes-here'
curl "https://$APIGEE_X_HOSTNAME/london/bikes/v1?apikey=$APIKEY&try=[1-10]" -I
```
