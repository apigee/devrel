#! /bin/bash
# shellcheck disable=SC2206
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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

# Enable API
# Console: https://pantheon.corp.google.com/apis/library/spanner.googleapis.com
gcloud services enable spanner.googleapis.com

# Using gcloud: https://cloud.google.com/spanner/docs/getting-started/gcloud
# Create instance
gcloud spanner instances create "$SPANNER_INSTANCE" --config="$SPANNER_REGION" --description="Product Catalog Instance" --nodes=1

# Set default instance
gcloud config set spanner/instance "$SPANNER_INSTANCE"

gcloud spanner databases create "$SPANNER_DATABASE" --instance "$SPANNER_INSTANCE"

# Create database
gcloud spanner databases ddl update "$SPANNER_DATABASE" \
--ddl='CREATE TABLE products (productid STRING(20) NOT NULL, name STRING(100), description STRING(1024), price FLOAT64, discount FLOAT64, image STRING(1024)) PRIMARY KEY(productid);'

# Add product data to Spanner
# Array of product Id data to be combined with Ids
DATAS[0]="description=Bamboo glass jar,discount=0,image=products_Images/bamboo-glass-jar.jpg,name=Bamboo glass jar,price=19.99"
DATAS[1]="description=Hotest hairdryer,discount=0,image=products_Images/hairdryer.jpg,name=Hairdryer,price=84.99"
DATAS[2]="description=Most comfortable loafers,discount=0,image=products_Images/loafers.jpg,name=Loafers,price=38.99"
DATAS[3]="description=Best Coffee Mug,discount=0,image=products_Images/mug.jpg,name=Coffee Mug,price=4.20"
DATAS[4]="description=The ultimate sunglasses,discount=0,image=products_Images/sunglasses.jpg,name=Aviator Sunglasses,price=42.42"

# Get list of IDs (5 total) from BigQuery based on the CUSTOMER_USERID to create in Spanner.
# Sort ascending, opposite of propensity to buy, to demonstrate different results.
# Result is one ID per line
IDS_JSON=$(bq query --format json --nouse_legacy_sql \
  "SELECT * FROM \`$PROJECT_ID.bqml.prod_recommendations\` AS A where A.userid = \"$CUSTOMER_USERID\" \
  ORDER BY A.predicted_session_duration_confidence ASC")
IDS=$(echo "$IDS_JSON" | jq -r .[].itemId)

# Convert to an array
# shellcheck disable=SC2206
IDS_ARR=($IDS)
for ((i = 0; i < ${#IDS_ARR[@]};  i++))
do
  echo -n "${IDS_ARR[$i]} - "
  gcloud spanner rows insert --database="$SPANNER_DATABASE" --table=products --data="productid=${IDS_ARR[$i]},${DATAS[$i]}"
done
gcloud spanner databases execute-sql "$SPANNER_DATABASE" --sql='SELECT * FROM products'


