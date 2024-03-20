# Apigee Target Server Validator

The objective of this tool to validate targets in Target Servers & Apigee API Proxy Bundles exported from Apigee.
Validation is done by deploying a sample proxy which check if HOST & PORT is open from Apigee.

> **NOTE**: Discovery of Targets in API Proxy & Sharedflows is limited to only parsing URL from `TargetEndpoint` & `ServiceCallout` Policy.

> **NOTE**: Dynamic targets are **NOT** supported, Ex : `https://host.{request.formparam.region}.example.com}`

## Pre-Requisites
* Python3.x
* Java
* Maven >= 3.9.6
* Please install the required Python dependencies
```
    python3 -m pip install -r requirements.txt
```
* Please build the java callout jar by running the below command

```
bash callout/build_java_callout.sh
```

* Please fill in `input.properties`

```
[source]
baseurl=https://x.x.x.x/v1                       # Apigee Base URL. e.g http://management-api.apigee-opdk.corp:8080
org=xxx-xxxx-xxx-xxxxx                           # Apigee Org ID
auth_type=basic                                  # API Auth type basic | oauth

[target]
baseurl=https://apigee.googleapis.com/v1         # Apigee Base URL
org=xxx-xxxx-xxx-xxxxx                           # Apigee Org ID
auth_type=oauth                                  # API Auth type basic | oauth

[csv]
file=input.csv                                   # Path to input CSV. Note: CSV needs HOST & PORT columns
default_port=443                                 # default port if port is not provided in CSV

[validation]
check_csv=true                                   # 'true' to validate Targets in input csv
check_proxies=true                               # 'true' to validate Proxy Targets else 'false'
skip_proxy_list=mock1,stream                     # Comma separated list of proxies to skip validation;
proxy_export_dir=export                          # Export directory needed when check_proxies='true'
api_env=dev                                      # Target Environment to deploy Validation API Proxy
api_name=target_server_validator                 # Target API Name of Validation API Proxy
api_force_redeploy=false                         # set 'true' to Re-deploy Target API Proxy
api_hostname=example.apigee.com                  # Target VirtualHost or EnvGroup Domain Name
api_ip=<IP>                                      # IP address corresponding to api_hostname. Use if DNS record doesnt exist
report_format=csv                                # Report Format. Choose csv or md (defaults to md)

[gcp_metrics]
enable_gcp_metrics=true                          # set 'true' to push target server's host and status to GCP metrics
project_id=xxx-xxx-xxx                           # Project id of GCP project where the data will be pushed
metric_name=custom.googleapis.com/<metric_name>  # Replace <metric_name> with custom metric name
enable_dashboard=true                            # set 'true' to create the dashboard with alerting policy
dashboard_title=Apigee Target Server Monitoring Dashboard  # Monitoring Dashboard Title
alert_policy_name=Apigee Target Server Validator Policy    # Alerting Policy Name
notification_channel_ids=xxxxxxxx                 # Comma separated list of Notification Channel ids

[target_server_state_file]
state_file=gs://bucket_name/path/to/file/scan_output.json  # GCS Bucket path to store --scan output
# state_file=file://scan_output.json             # File path to store --scan output (only one can be used either GCS or file)
gcs_project_id=xxx-xxxx-xxx-xxxxx                # GCS bucket project id
```

To get the notification channel id, use the following command

```
gcloud beta monitoring channels list --project=<project_id>
```

This command will display all available notification channels within your project. You can select the appropriate one based on your requirements. Locate the notification channel ID under the `name` field in the format `projects/<project_id>/notificationChannels/<notification_channel_id>`, and insert it into the input.properties file.


* Sample input CSV with target servers
> **NOTE:** You need to set `check_csv=true` in the `validation` section of `input.properties`

> **NOTE:** You need to set `file=<CSV Name>` in the `csv` section of `input.properties`
> If PORT is omitted from the csv, the value of default_port will be used from `input.properties`.
```
HOST,PORT
httpbin.org
mocktarget.apigee.net,80
smtp.gmail.com,465
```


* Please run below commands to authenticate, 

```
gcloud auth application-default set-quota-project <project_id>
```
You can skip the quota-project if you want.

Another way to authenticate is to use the environmnet variables based on the Apigee flavours.

```
export APIGEE_OPDK_ACCESS_TOKEN=$(echo -n "<user>:<password>" | base64) # Access token for Apigee OPDK
export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)            # Access token for Apigee X/Hybrid
```

## Highlevel Working 
* Export Target Server Details
* Export Proxy Bundle 
* Parse Each Proxy Bundle for Target
* Run Validate API against each Target (optional)
* Generate csv/md Report or push data to GCP Monitoring Dashboard

## Usage

The script supports the below arguments

* `--onboard`               option to create validator proxy, custom metric descriptors and dashboard
* `--scan`                  option to fetch target servers from Environment target servers, api proxies & csv file
* `--monitor`               option to check the status of target servers and generate report or push to GCP metrics
* `--input`                 Path to input properties file

To onboard, run
```
python3 main.py --input path/to/input_file --onboard 
```
Make sure you have build the java callout jar before running onboard.

To scan, run
```
python3 main.py --input path/to/input_file --scan
```

To monitor, run
```
python3 main.py --input path/to/input_file --monitor
```

You can also pass multiple arguments at the same time.

--onboard deploys an API proxy to validate if the target servers are reachable or not. To use the API proxy, make sure your payloads adhere to the following format:

```json
[
    {
        "host": "example.com",
        "port": 443
    },
    {
        "host": "example2.com",
        "port": 443
    },
    // Add up to 8 more host-port combinations as needed
]
```

The response will look like this - 
```json
[
    {
        "host": "example.com",
        "port": 443,
        "status" : "REACHABLE"
    },
    {
        "host": "example2.com",
        "port": 443,
        "status" : "UNKNOWN_HOST"
    },
    // and so on 
]
```

## Report
Validation Report: `report.md` OR `report.csv` can be found in the same directory as the script.

Please check a [Sample report](report.md)

## GCP Monitoring Dashboard
The script can also create a GCP Monitoring Dashboard with an alerting widget like shown below:

![GCP Monitoring Dashboard](images/dashboard.png)

This script creates a custom metric with labels as hostname and status. The possible statuses, namely REACHABLE NOT_REACHABLE, and UNKNOWN_HOST, are determined by calling the validator proxy. These statuses are then assigned values of 1, 0.5, and 0, respectively.

Then, an alerting policy is created with a threshold of 0.75. Entries below this threshold trigger alerts sent to designated notification channels. Finally, this policy is added as a widget on the GCP dashboard.

# Running the Pipeline

To run the pipeline script (`pipeline.sh`), follow these steps:

## Prerequisites

Before running the pipeline script, ensure you have the following prerequisites configured:

- **Environment Variables**: Set up the necessary environment variables required by the script. These variables should include:
  - `APIGEE_X_ORG`: Your Apigee organization ID.
  - `APIGEE_X_ENV`: The Apigee environment to deploy to.
  - `APIGEE_X_HOSTNAME`: The hostname for your Apigee instance.

  *NOTE*: This pipeline will create a test notification channel with type email and email_address as `no-reply@google.com`.

- **Input Properties Template**: This script requires an `input.properties` file for the necessary configuration parameters and will create a corresponding `generated.properties` file by replacing the environment variables with their values. Ensure that the values are set properly in this file before running the script.

## Running the Pipeline

### Command

To execute the pipeline, use the following command:

```
./pipeline.sh
```