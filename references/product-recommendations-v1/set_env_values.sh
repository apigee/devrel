# Example script to set environmenet variables.

# Change to your values
export PROJECT_ID=your_org_name
export ORG=$PROJECT_ID
export ENV=your_env
export ENVGROUP_HOSTNAME=your_hostname.your_domain.net
export SPANNER_REGION=regional-us-east1
export SA=datareader@$ORG.iam.gserviceaccount.com
export CUSTOMER_USERID="6929470170340317899-1"

# No need to change these
export SPANNER_INSTANCE=product-catalog
export SPANNER_DATABASE=product-catalog-v1
APIKEY=$(curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    https://apigee.googleapis.com/v1/organizations/$ORG/developers/demo@any.com/apps/product-recommendations-v1-app-$ENV \
    | jq -r .credentials[0].consumerKey)

