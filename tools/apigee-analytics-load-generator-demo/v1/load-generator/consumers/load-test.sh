USR=$1
PASS=$2
APIGEE_ORG=$3
APIGEE_ENV=$4
TOKEN=$(echo "$USR:$PASS\c" | base64)
APIGEE_URL="https://api.enterprise.apigee.com/v1/organizations/"$APIGEE_ORG"/"

env TOKEN=$TOKEN APIGEE_URL="https://api.enterprise.apigee.com/v1/organizations/"$APIGEE_ORG"/" locust --host=https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/v1 --no-web -c 1 -r 1 -f locust-load.py