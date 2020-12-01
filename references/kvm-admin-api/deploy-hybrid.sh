zip -r apiproxy.zip apiproxy/*

export TOKEN=$(gcloud auth print-access-token)
export PROJECT_ID=$(gcloud config get-value project)
export APIGEE_HYBRID_ENV=test

PROXY_REV=$(curl -X POST \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}/apis?action=import&name=kvm-admin-v1&validate=true" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: multipart/form-data" \
    -F "zipFile=@./apiproxy.zip" | grep '"revision": "[^"]*' | cut -d'"' -f4)

rm "./apiproxy.zip"

curl -X POST \
    "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}/environments/$APIGEE_HYBRID_ENV/apis/kvm-admin-v1/revisions/${PROXY_REV}/deployments?override=true" \
    -H "Authorization: Bearer $TOKEN"