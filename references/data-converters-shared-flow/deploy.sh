TOKEN=$(gcloud auth print-access-token)
zip -r sf-data-converters.zip sharedflowbundle
DEPLOYRESULT=$(curl -X POST -H "Content-Type:multipart/form-data" -H "Authorization:Bearer $TOKEN" -F "file=@\"./sf-data-converters.zip\" type=application/zip;filename=\"sf-data-converters.zip\"" 'https://apigee.googleapis.com/v1/organizations/'$APIGEE_X_ORG'/sharedflows?name=SF-Data-Converters&action=import')
echo "$DEPLOYRESULT"
REVISION=$(jq '.revision' <<< "$DEPLOYRESULT")
echo "$REVISION"
NEWREV="${REVISION%\"}"
NEWREV="${NEWREV#\"}"
echo "$NEWREV"
#gcloud apigee apis deploy $NEWREV --environment=$ENV --api=SF-Data-Converters --override
UPDATERESULT=$(curl -X POST -H "Authorization:Bearer $TOKEN" 'https://apigee.googleapis.com/v1/organizations/'$APIGEE_X_ORG'/environments/'$APIGEE_X_ENV'/sharedflows/SF-Data-Converters/revisions/'$NEWREV'/deployments' -d "override=true")
echo "$UPDATERESULT"
