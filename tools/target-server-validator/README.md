# Apigee Target Server Validator

The objective of this tool to validate targets in Target Servers & Apigee API Proxy Bundles exported from Apigee OPDK/X/Hybrid.
Validation is done by deploying a sample proxy which check if HOST & PORT is open from Apigee OPDK/X/Hybrid.

> **NOTE**: Discovery of Targets in API Proxy & Sharedflows is limited to only parsing URL from `TargetEndpoint` & `ServiceCallout` Policy.

> **NOTE**: Dynamic targets are **NOT** supported, Ex : `https://host.{request.formparam.region}.example.com}`

## Disclaimer
This is not an Officially Supported Google Product!

## Pre-Requisites
* python3.x
* Please Install required Python Libs 

```
    python3 -m pip install requirements.txt
```
* Please fill in `input.properties`

```
[source]
baseurl=http://34.131.144.184:8080/v1       # Apigee OPDK/Edge/X/Hybrid Base URL
org=xxx-xxxx-xxx-xxxxx                      # Apigee OPDK/Edge/X/Hybrid Org
auth_type=basic                             # API Auth type basic | oauth

[target]
baseurl=https://apigee.googleapis.com/v1    # Apigee OPDK/Edge/X/Hybrid Base URL
org=xxx-xxxx-xxx-xxxxx                      # Apigee OPDK/Edge/X/Hybrid Org Id
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
vhost_domain_name=devgroup                  # Target VHost or EnvGroup
vhost_ip=<IP>                               # IP address corresponding to vhost_domain_name. Use if DNS record doesnt exist
report_format=csv                           # Report Format. Choose csv or md (Markdown)
```

* Sample input CSV with target servers
> **NOTE:** You need to set `check_csv=true` in the `validation` section of `input.properties`

> **NOTE:** You need to set `file=<CSV Name>` in the `csv` section of `input.properties`

```
HOST,PORT
httpbin.org
mocktarget.apigee.net,80
smtp.gmail.com,465
```


* Please run below command to authenticate against Apigee X/Hybrid APIS

```
    export APIGEE_OPDK_ACCESS_TOKEN=$(echo -n "<user>:<password>" | base64) # Access token for Apigee OPDK
    export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)            # Access token for Apigee X
```

## Highlevel Working 
* Export Target Server Details
* Export Proxy Bundle 
* Parse Each Proxy Bundle for Target
* Run Validate API against each Target
* Generate CSV Report

## Usage

Run the Script as below
```
python3 main.py
```

## Report
Validation Report : `report.md` OR `report.csv` can be accessed in same localtion as script.

Please check a [Sample report](report.md)

## Copyright

Copyright 2023 Google LLC. This software is provided as-is, without warranty or representation for any use or purpose. Your use of it is subject to your agreement with Google.
