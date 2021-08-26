GCP_TOKEN=$1
APIGEE_ORG=$2
APIGEE_ENV=$3
HOST=$4
WORKLOAD_LEVEL=$5
if [ $WORKLOAD_LEVEL = "high" ]; then
    concurrent=15
    requests=20
fi
if [ $WORKLOAD_LEVEL = "medium" ]; then
    concurrent=8
    requests=10
fi
if [ $WORKLOAD_LEVEL = "low" ]; then
    concurrent=1
    requests=5
fi

env TOKEN=$GCP_TOKEN APIGEE_ORG=$APIGEE_ORG APIGEE_ENV=$APIGEE_ENV locust --host=https://$HOST/v1 --no-web -c $concurrent -r $requests -f locust-load.py