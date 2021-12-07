#! /bin/bash

echo; echo Using Apigee X project \""$PROJECT_ID"\", instance \""$SPANNER_INSTANCE"\", database \""$SPANNER_DATABASE"\" in region \""$SPANNER_REGION"\" for CUSTOMER_USERID \""$CUSTOMER_USERID"\"
read -r -p "OK to proceed (Y/n)? " i
if [ "$i" != "Y" ]
then
  echo aborted
  exit 1
fi
echo Proceeding...

# Set project for gcloud commands 
gcloud config set project "$PROJECT_ID"

# Using gcloud: https://cloud.google.com/spanner/docs/getting-started/gcloud
# Delete database 
gcloud spanner databases delete "$SPANNER_DATABASE" --quiet

# Delete  instance
gcloud spanner instances delete "$SPANNER_INSTANCE" --quiet