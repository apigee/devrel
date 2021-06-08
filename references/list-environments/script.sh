curl -s https://apigee.googleapis.com/v1/organizations/apigee-hybrid-org -H "Authorization: Bearer $(gcloud auth print-access-token)" | jq ".environments[]" -r
