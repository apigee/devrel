# v2

The intended use case of this project is to generate traffic towards Apigee to demo Analytics and tracing. This is not a performance testing project.

This code will spin an instance, deploy assets to Apigee X or Hybrid and , using Locust, will send traffic to those assets.


## Install - deploying the demo

1. Clone [this](https://github.com/igalonso/apigee-analytics-load-generator-demo) project in your local folder. Go to the V2 folder.

2. Create a [service account](https://cloud.google.com/iam/docs/creating-managing-service-accounts) with GCP onwer role permissions (to be modified in future releases). Generate a [key](https://cloud.google.com/iam/docs/creating-managing-service-account-keys) and save it in the project root folder with the name ```load-generator-key.json```.
3. Run 
```
export GCLOUDTOKEN=$(gcloud auth print-access-token)

sh init.sh --action launch --apigee-token $GCLOUDTOKEN --apigee-org APIGEE_ORG --apigee-env APIGEE_ENV --gcp-apigee-project GPROJECT_APIGEE --gcp-project GPROJECT_GCP --apigee-url APIGEE_URL --uuid RANDOM_NUMBER --deployment (gcp || apigee || backends || all) --workload-level (high || medium || low)
```

* **--action**: ```launch``` to start the load generator or ```delete``` to remove the load generator

* **--apigee-token**: GCP Token to deploy Apigee. Recommended to use ```gcloud auth print-access-token```

* **--apigee-org**: Apigee Organization to deploy to.

* **--apigee-env**: Apigee Environment to use under previous organization.

* **--gcp-apigee-project**: Google Cloud Project ID where Apigee X or Hybrid resides.

* **--gcp-project**: Google Cloud Project ID where the VMs and backends will be deployed to.

* **--apigee-url**: Apigee Full Qualified Hostname for the specific environment group.

* **--uuid**: Random number that you will need to remember (to support multiple instances of this demo within the same org) in order to delete this deployment afterwards..

* **--deployment**: What do you want to deploy or undeploy? Values ```all```, ```gcp```, ```backends``` or ```apigee```

* **--workload-level**: How much traffic you want to send? Values ```medium```, ```low``` or ```high```

4. Wait! It should deploy everything and provide a reliable traffic pattern to your Apigee organization.

5. Delete the service account and key to avoid security breaches.

## Delete demo

Within the project folder (*apigee-analytics-load-generator-demo*), execute the following command:

```
export GCLOUDTOKEN=$(gcloud auth print-access-token/v2)

sh init.sh --action delete --apigee-token $GCLOUDTOKEN --apigee-org APIGEE_ORG --apigee-env APIGEE_ENV --gcp-apigee-project GPROJECT_APIGEE --gcp-project GPROJECT_GCP  --apigee-url APIGEE_URL --uuid RANDOM_NUMBER --deployment (gcp || apigee || all) --workload-level (high || medium || low)
```

* **--action**: ```launch``` to start the load generator or ```delete``` to remove the load generator

* **--apigee-token**: GCP Token to deploy Apigee. Recommended to use ```gcloud auth print-access-token```

* **--apigee-org**: Apigee Organization to deploy to.

* **--apigee-env**: Apigee Environment to use under previous organization.

* **--gcp-apigee-project**: Google Cloud Project ID where Apigee X or Hybrid resides.

* **--gcp-project**: Google Cloud Project ID where the VMs will be deployed to.

* **--appengine**: Google Cloud App Engine app name that will be used.

* **--apigee-url**: Apigee URL for the specific environment group.

* **--appengine-domain**: Domain name for your backends.

* **--gcp-svc-account-email**: Service account email used for the deployment of VMs.

* **--uuid**: Previous random number (when deploying)

* **--deployment**: What do you want to deploy or undeploy? Values ```all```, ```gcp``` or ```apigee```

* **--workload-level**: How much traffic you want to send? Values ```medium```, ```low``` or ```high```
