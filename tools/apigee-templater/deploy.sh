#!/bin/bash

PROJECT_ID=$(gcloud config get-value project)

gcloud builds submit --tag "eu.gcr.io/$PROJECT_ID/apigee-templater"

gcloud run deploy apigee-templater --image "eu.gcr.io/$PROJECT_ID/apigee-templater" --platform managed --project "$PROJECT_ID" \
	--region europe-west1 --allow-unauthenticated
