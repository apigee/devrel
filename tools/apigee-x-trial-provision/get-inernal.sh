


curl -i -H "$AUTH" -X GET \
  -H "Content-Type:application/json" \
  https://apigee.googleapis.com/v1/organizations/ORG_NAME/instances/INSTANCE_NAME


export ORG=$PROJECT


INSTANCE=$(curl --silent -H "Authorization: Bearer $(token)" -H "Content-Type:application/json" https://apigee.googleapis.com/v1/organizations/$ORG/instances | jq .instances[0].name --raw-output)

curl -H "Authorization: Bearer $(token)" \
     -H "Content-Type:application/json" \
  https://apigee.googleapis.com/v1/organizations/$ORG/instances/$INSTANCE

 -H "Content-Type: application/json" https://apigee.googleapis.com/v1/organizations?parent=projects/$


curl -H "Authorization: Bearer $(token)" -H "Content-Type: application/json" https://apigee.googleapis.com/v1/organizations?parent=projects/$PROJECT --data-binary @- <<EOF
{
    "name":"$ORG",
    "displayName":"$ORG",
    "description":"organization_description",
    "runtimeType":"HYBRID",
    "analyticsRegion":"$AX_REGION"
}
EOF



## delete resoruces to recreate lbs

gcloud compute ssl-certificates delete apigee-ssl-cert  --project $PROJECT 

load balancer
intance group
instance template