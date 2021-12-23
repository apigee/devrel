# Smart API to Predict Customer Propensity to buy using Apigee, BigQuery ML and Cloud Spanner
## Overview
This demo shows how to bild a smart API that predicts customer propensity to buy using an Apigee X or Hybrid proxy, BigQuery ML and Cloud Spanner.

BigQuery contains a sample dataset for the Product Catalog Ids and a number of simulated users.
It uses Machine Learning to add their propensity to buy based on the time the user spends viewing an item, termed the "predicted session duration confidence", which is a numerical value ordered descending (higher is more likely to buy).

Cloud Spanner contains a Product Catalog with rich content, such as descriptions and image references. The demo only contains entries for a specific customer Id.
The items in Spanner are created and ordered differently than the BigQuery result (e.g ascending by name).

Apigee exposes an API that proxies to BigQuery to get the product Ids and the "predicted session duration confidence" for a particular user and then makes a callout to Spanner to get the additional product content.
The proxy then uses both responses to create the priority sorted result that is sent in the response.

### Architecture Diagram
![Architecture Diagram](product-recommendations-v1.png)

Step Descriptions:
1. Client request to GET /v1/recommendations/products with API Key and User Id.
2. Apigee extracts user Id from request header (see note), creates a SQL query using Assign Message policy, sends that to BigQuery and processes the response.
3. Apigee creates a [Spanner session](https://cloud.google.com/spanner/docs/sessions) via Service Callout policy and stores the session name.
4. Apigee then creates a SQL query for Spanner using another Service Callout policy to get the ordered response based on the BigQuery prepensity rating returned from BigQuery.
5. Finally, Apigee formats the response using JavaScript to match the response definition from the Open API Specification.

**NOTE:**
Passing the user Id as a header value is done for the purposes of the demo.
In a real-world solution, it would be provided via a separate authentication flow and passed as token in the Authorization header.

## Prerequisites
This demo relies on the use of a GCP Project for [Apigee](https://cloud.google.com/apigee), [Big Query](https://cloud.google.com/bigquery) and [Cloud Spanner](https://cloud.google.com/spanner).

**NOTE:**
If you don't have an Apigee organization you can [provision an evaluation organization](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro).

The demo uses [gcloud](https://cloud.google.com/sdk/gcloud), [Maven](https://maven.apache.org/), and [jq](https://github.com/stedolan/jq), all of which can be run from the gcloud shell without any installation.

The API proxy uses a Service Account (e.g. datareader) for GCP authentication to access Big Query and Spanner.\
We'll use a separate Service Account (e.g. demo-installer) to setup BigQuery, Spanner and Apigee.\
It will have the following roles:
- Apigee Organization Admin
- BigQuery Admin
- Cloud Spanner Admin
- Service Account User

### Overview of Steps
As Project Owner
1. First [set environment variables](#set-environment-variables) and [enable APIs](#enable-apis).
2. Using an existing GCP Project or after creating a GCP Project, [create Service Accounts for proxy deployment and installer](#create-service-accounts).
3. Install a sample dataset using [Setup BigQuery Recommendations Dataset](#setup-bigquery-recommendations-dataset).
4. Install a Product Catalog using [Setup Spanner Product Catalog](#setup-spanner-product-catalog).
5. Install Apigee proxy using the [Maven command](#setup-apigee-x-proxy).
6. [Test the API proxy](#test-the-api-proxy).
7. Remove created artifacts in the [Cleanup](#cleanup) section (optional).

## Setup

### Set Environment Variables
Create a copy of the [set_env_variables.sh](set_env_variables.sh) file with your values for easy replay via "source set_env_variables_my_apigeex.sh":
```lang-shell
# Change to your values
export PROJECT_ID=your_org_name
gcloud config set project "$PROJECT_ID"
export ORG=$PROJECT_ID
export ENV=your_env
export ENVGROUP_HOSTNAME=your_api_domain_name

# No need to change these
export SPANNER_INSTANCE=product-catalog
export SPANNER_DATABASE=product-catalog-v1
export SPANNER_REGION=regional-us-east1
export SA=datareader@$PROJECT_ID.iam.gserviceaccount.com
```
Other environment variables that are set below:
```lang-shell
# For Apigee proxy deployment and API calls
CUSTOMER_USERID
APIKEY
```

### Enable APIs
Enable APIs for BigQuery and Spanner.
```lang-shell
gcloud services enable bigquery.googleapis.com 
gcloud services enable spanner.googleapis.com
```

## Create Service Account
Create the "datareader" service account that is used during proxy deployment.
```lang-shell
gcloud iam service-accounts create datareader --project="$PROJECT_ID" --display-name="Data reader in Apigee proxy for BQ and Spanner Demo"
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA" --role="roles/spanner.databaseUser" --quiet
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA" --role="roles/spanner.databaseReader" --quiet
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA" --role="roles/bigquery.dataViewer" --quiet
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA" --role="roles/bigquery.user" --quiet
```


## Setup BigQuery Recommendations Dataset
BigQuery contains an example dataset and table that shows a subset of results from a BigQuery Machine Learning training computation.

Run the [setup_bigquery.sh](setup_bigquery.sh) shell script to create the Dataset and table.
It outputs the entries from the table which contains multiple `userId`s.\
Output:
```lang-shell
+-----------------------+----------------+---------------------------------------+
|        userId         |     itemId     | predicted_session_duration_confidence |
+-----------------------+----------------+---------------------------------------+
| 3199127724637190357-1 | GGOEGAAX0037   |                    38558.716565696246 |
| 3199127724637190357-1 | GGOEYDHJ056099 |                     33550.24722825712 |
| 3199127724637190357-1 | GGOEGAAX0318   |                     26528.89888944023 |
| 3199127724637190357-1 | GGOEGAAX0351   |                    26482.668847416397 |
| 3199127724637190357-1 | GGOEGAAX0568   |                     24279.21602975858 |
| 6929470170340317899-1 | GGOEGAAX0037   |                     40161.10446942589 |
| 6929470170340317899-1 | GGOEYDHJ056099 |                     27642.28480729123 |
| 6929470170340317899-1 | GGOEGAAX0351   |                    27204.111219270915 |
| 6929470170340317899-1 | GGOEGDWC020199 |                    25863.861349754334 |
| 6929470170340317899-1 | GGOEGAAX0318   |                    24585.509088154067 |
| 8147666854244452077-2 | GGOEGAAX0037   |                     40305.68799444366 |
| 8147666854244452077-2 | GGOEYDHJ056099 |                    32990.653160073765 |
| 8147666854244452077-2 | GGOEGBRA037499 |                    29955.508214236765 |
| 8147666854244452077-2 | GGOEGAAX0568   |                     27424.47289919785 |
| 8147666854244452077-2 | GGOEGAAX0351   |                     27303.99191214219 |
| 9405044354008242178-1 | GGOEGDWC020199 |                    32839.463106886644 |
| 9405044354008242178-1 | GGOEGAAX0351   |                    29849.140860385953 |
| 9405044354008242178-1 | GGOEGBRA037499 |                    26122.819361915943 |
| 9405044354008242178-1 | GGOEGAAX0037   |                    25299.639807373154 |
| 9405044354008242178-1 | GGOEGEVR014999 |                    25213.664943515258 |
+-----------------------+----------------+---------------------------------------+
```

Choose one of the `userId` values and set the CUSTOMER_USERID environment variable, we'll use that in the API proxy and API calls later.

Now run a BigQuery query command to show the "prediction" ordered results for a specific user.

For example:

```lang-shell
export CUSTOMER_USERID=6929470170340317899-1

bq query --nouse_legacy_sql \
    "SELECT * FROM \`$PROJECT_ID.bqml.prod_recommendations\` AS A where A.userid = \"$CUSTOMER_USERID\"" \
    ORDER BY A.predicted_session_duration_confidence DESC
```
Example response:
```lang-shell
+-----------------------+----------------+---------------------------------------+
|        userId         |     itemId     | predicted_session_duration_confidence |
+-----------------------+----------------+---------------------------------------+
| 6929470170340317899-1 | GGOEGAAX0037   |                     40161.10446942589 |
| 6929470170340317899-1 | GGOEYDHJ056099 |                     27642.28480729123 |
| 6929470170340317899-1 | GGOEGAAX0351   |                    27204.111219270915 |
| 6929470170340317899-1 | GGOEGDWC020199 |                    25863.861349754334 |
| 6929470170340317899-1 | GGOEGAAX0318   |                    24585.509088154067 |
+-----------------------+----------------+---------------------------------------+
```

## Setup Spanner Product Catalog
The Spanner Product Catalog will only contain the items that where used in the BigQuery training step for a specific user. We'll create product entries using those `itemID`s. This means that if you change the  `CUSTOMER_USERID` you may see different results or sparse results as Spanner does not contain the entire product catalog.

**NOTE:** The order in which the items are returned from Spanner is different than those returned from BigQuery. This allows us to observe the differences from the "prediction".

Run the [setup_spanner.sh](setup_spanner.sh) shell script to set up Spanner Product Catalog.
It uses the `CUSTOMER_USERID` and outputs the entries that where created.

You can also run a gcloud command to view, for example:
```lang-shell
gcloud spanner databases execute-sql $SPANNER_DATABASE --project=$PROJECT_ID --sql='SELECT * FROM products'
```
Sample response:
```lang-shell
productid       name                description               price  discount  image
GGOEGAAX0037    Aviator Sunglasses  The ultimate sunglasses   42.42  0         products_Images/sunglasses.jpg
GGOEGAAX0318    Bamboo glass jar    Bamboo glass jar          19.99  0         products_Images/bamboo-glass-jar.jpg
GGOEGAAX0351    Loafers             Most comfortable loafers  38.99  0         products_Images/loafers.jpg
GGOEGDWC020199  Hairdryer           Hotest hairdryer          84.99  0         products_Images/hairdryer.jpg
GGOEYDHJ056099  Coffee Mug          Best Coffee Mug           4.2    0         products_Images/mug.jpg
```

## Setup Apigee Proxy
The Apigee proxy will be deployed using Maven.
The Maven command will create and deploy a proxy (product-recommendations-v1), create an API Product (product-recommendations-v1-$ENV), create an App Developer (demo@any.com) and App (product-recommendations-v1-app-$ENV).

Note the pom.xml file profile values for `apigee.org`, `apigee.env`, `api.northbound.domain`, `gcp.projectid`, `googletoken.email` and `api.userid`. These values vary by project and will be set via the command line.
```lang-xml
<profile>
  <id>eval</id>
  <properties>
    <apigee.profile>eval</apigee.profile>
    <apigee.org>${apigeeOrg}</apigee.org>
    <apigee.env>${apigeeEnv}</apigee.env>
    <api.northbound.domain>${envGroupHostname}</api.northbound.domain>
    <gcp.projectid>${gcpProjectId}</gcp.projectid>
    <apigee.googletoken.email>${googleTokenEmail}</apigee.googletoken.email>
    <api.userid>${integrationTestUserId}</api.userid>
  </properties>
</profile>
```

Run Maven to install the proxy and its associated artifacts and then test the API, all in one command.
```lang-shell
mvn -P eval clean install -Dbearer=$(gcloud auth print-access-token) \
    -DapigeeOrg=$ORG \
    -DapigeeEnv=$ENV \
    -DenvGroupHostname=$ENVGROUP_HOSTNAME \
    -DgcpProjectId=$PROJECT_ID \
    -DgoogleTokenEmail=$SA \
    -DintegrationTestUserId=$CUSTOMER_USERID
```
The result of the maven command shows the integration test output, one to `/openapi` and another to `/products`.
It also displays the App credentials which can be used for susequent API test calls.

## Testing the API Proxy
You can get the API Key for the App using the Apigee API:
```lang-shell
APIKEY=$(curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    https://apigee.googleapis.com/v1/organizations/$ORG/developers/demo@any.com/apps/product-recommendations-v1-app-$ENV \
    | jq -r .credentials[0].consumerKey)
```

Then test using curl, for example:
```lang-shell
curl -s https://$ENVGROUP_HOSTNAME/v1/recommendations/products -H "x-apikey:$APIKEY" -H "x-userid:$CUSTOMER_USERID" | jq
```

The API defined by the Open API Specification in [product-recommendations-v1-oas.yaml](product-recommendations-v1-oas.yaml) allows the request to specify headers:
* x-apikey: the App consumer key as per security scheme
* x-userid: the user identifier making the request (defaults to 6929470170340317899-1 in the proxy if not provided).
* cache-control: cache the response for 300 seconds or override by specifying "no-cache".

Example:
```lang-shell
curl -s "https://$ENVGROUP_HOSTNAME/v1/recommendations/products" \
-H "x-apikey:$APIKEY" \
-H "x-userid:$CUSTOMER_USERID" \
-H "Cache-Control:no-cache" | jq
```
Example response:
```lang-json
{
  "products": [
    {
      "productid": "GGOEGAAX0037",
      "name": "Aviator Sunglasses",
      "description": "The ultimate sunglasses",
      "price": "42.42",
      "image": "products_Images/sunglasses.jpg"
    },
    {
      "productid": "GGOEYDHJ056099",
      "name": "Coffee Mug",
      "description": "Best Coffee Mug",
      "price": "4.2",
      "image": "products_Images/mug.jpg"
    },
    {
      "productid": "GGOEGAAX0351",
      "name": "Loafers",
      "description": "Most comfortable loafers",
      "price": "38.99",
      "image": "products_Images/loafers.jpg"
    },
    {
      "productid": "GGOEGDWC020199",
      "name": "Hairdryer",
      "description": "Hotest hairdryer",
      "price": "84.99",
      "image": "products_Images/hairdryer.jpg"
    },
    {
      "productid": "GGOEGAAX0318",
      "name": "Bamboo glass jar",
      "description": "Bamboo glass jar",
      "price": "19.99",
      "image": "products_Images/bamboo-glass-jar.jpg"
    }
  ]
}
```
## Key Takeaway
The order of the items in the API response is that provided by BigQuery and is a different order than the output from Spanner. That's because the API proxy first gets the "prediction" ordered results from BigQuery and then combines that with the product details from Spanner.

## Cleanup
You can cleanup your project rather than deleting the entire project as you may want to continue to use Apigee.

### Cleanup Apigee (optional)
Run Maven to undeploy and delete proxy and it's associated artifacts, all in one command.
```lang-shell
mvn -P eval process-resources -Dbearer=$(gcloud auth print-access-token) \
    -DapigeeOrg=$ORG -DapigeeEnv=$ENV -Dskip.integration=true \
    apigee-config:apps apigee-config:apiproducts apigee-config:developers -Dapigee.config.options=delete \
    apigee-enterprise:deploy -Dapigee.options=clean
```

### Cleanup Spanner (optional)
Remove the Spanner resources by running the [cleanup_spanner.sh](cleanup_spanner.sh) shell script.

### Cleanup BigQuery (optional)
Remove BigQuery resouces by running the [cleanup_bigquery.sh](cleanup_bigquery.sh)

### Delete Service Account (optional)
```lang-shell
gcloud iam service-accounts delete "$SA" --project="$PROJECT_ID" --quiet
```