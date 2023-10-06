# Apigee Target Server Validator

The objective of this tool to validate targets in Target Servers & Apigee API Proxy Bundles exported from Apigee.
Validation is done by deploying a sample proxy which check if HOST & PORT is open from Apigee.

> **NOTE**: Discovery of Targets in API Proxy & Sharedflows is limited to only parsing URL from `TargetEndpoint` & `ServiceCallout` Policy.

> **NOTE**: Dynamic targets are **NOT** supported, Ex : `https://host.{request.formparam.region}.example.com}`

## Pre-Requisites
* Python3.x
* Java
* Maven
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
baseurl=https://x.x.x.x/v1                  # Apigee Base URL. e.g http://management-api.apigee-opdk.corp:8080
org=xxx-xxxx-xxx-xxxxx                      # Apigee Org ID
auth_type=basic                             # API Auth type basic | oauth

[target]
baseurl=https://apigee.googleapis.com/v1    # Apigee Base URL
org=xxx-xxxx-xxx-xxxxx                      # Apigee Org ID
auth_type=oauth                             # API Auth type basic | oauth

[csv]
file=input.csv                              # Path to input CSV. Note: CSV needs HOST & PORT columns
default_port=443                            # default port if port is not provided in CSV

[validation]
check_csv=true                              # 'true' to validate Targets in input csv
check_proxies=true                          # 'true' to validate Proxy Targets else 'false'
skip_proxy_list=mock1,stream                # Comma sperated list of proxies to skip validation;
proxy_export_dir=export                     # Export directory needed when check_proxies='true'
api_env=dev                                 # Target Environment to deploy Validation API Proxy
api_name=target_server_validator            # Target API Name of Validation API Proxy
api_force_redeploy=false                    # set 'true' to Re-deploy Target API Proxy
api_hostname=example.apigee.com             # Target VirtualHost or EnvGroup Domain Name
api_ip=<IP>                                 # IP address corresponding to api_hostname. Use if DNS record doesnt exist
report_format=csv                           # Report Format. Choose csv or md (defaults to md)
```

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


* Please run below commands to authenticate, based on the Apigee flavours you are using.

```
export APIGEE_OPDK_ACCESS_TOKEN=$(echo -n "<user>:<password>" | base64) # Access token for Apigee OPDK
export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)            # Access token for Apigee X/Hybrid
```

## Highlevel Working 
* Export Target Server Details
* Export Proxy Bundle 
* Parse Each Proxy Bundle for Target
* Run Validate API against each Target (optional)
* Generate csv/md Report

## Usage

Run the script as below
```
python3 main.py
```

## Report
Validation Report: `report.md` OR `report.csv` can be found in the same directory as the script.

Please check a [Sample report](report.md)
