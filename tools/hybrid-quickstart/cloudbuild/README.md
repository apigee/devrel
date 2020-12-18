# Apigee hybrid Cloud Build Setup

If you run the Apigee hybrid quickstart from a workstation where you don't have
access to the necessary tools such as kubectl or want to create a hybrid cluster
in a GitOps pipeline, you can use this configuration that uses Google Cloud
Build to create the hybrid runtime for you.

## Prerequisites

To limit the permission scope of the Cloud Build service account we create the
required service accounts and enable all required APIS beforehand.

### Initialize project-level APIs

First you need to enable all required APIs. You can use the function in the
steps.sh file or enable them manually via the UI or API.

```sh
# from within the apigee hybrid quickstart folder
source steps.sh
enable_all_apis
```

### Create service accounts

You can use apigeectl to create the service accounts or create them manually via
the UI or API according to the documentation.

```sh
# from within the apigee hybrid quickstart folder
source steps.sh
set_config_params
download_apigee_ctl
create_sa
```

## Cloud Build SA Permissions

To set up the Apigee runtime the Cloud Build service account needs the following
permissions.

* Cloud Build Service Account
* Project Editor
* Kubernetes Engine Admin
* Kubernetes Engine Cluster Admin
* Service Account Key Admin

You can issue them manually via the UI or with the following script:

```sh
gcloud services enable cloudbuild.googleapis.com

PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")

for ROLE in container.admin container.clusterAdmin editor iam.serviceAccountKeyAdmin cloudbuild.builds.builder
do
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
   --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
   --role="roles/$ROLE"
done
```

## Submit Cloud Build Job

To trigger a cloud build you can use the following command or create your own
triggers in Cloud Build.

```sh
# from within the cloudbuild folder
gcloud builds submit --config hybrid.cloudbuild.yaml
```
