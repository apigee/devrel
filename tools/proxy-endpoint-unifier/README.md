# Apigee OPDK to Apigee X/Hybrid API Proxy Endpoint Unifier


## Objective
Apigee X has a limitation of hosting only 5 Proxy Endpoints per proxy.Apigee OPDK /Edge has no such limitaion.
Objective is take a proxy bundle and smartly convert them into conditional flows and group them with other proxy endpoints.

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
    [common]
    input_apis=apis                                     # Folder Containing Extracted Proxy Bundles
    processed_apis=transformed                          # Folder to export transfored Proxies to 
    proxy_bundle_directory=transformed_bundles          # Folder to export transfored Proxies Bundles (zip) to 
    proxy_endpoint_count=4                              # Number of Proxy Endpoint to retain while transforming
    debug=false                                         # Flag to export debug logs

    [validate]
    enabled=true                                        # Flag to enable Validation
    gcp_project_id=apigee-payg-377208                   # Apigee X/Hybrid Project to run Validation
```

* Please run below command to authenticate against Apigee X/Hybrid APIS if Validation  is enabled

```
    export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)
```


## Running
Run the Script as below
```
python3 main.py
```


## Copyright

Copyright 2023 Google LLC. This software is provided as-is, without warranty or representation for any use or purpose. Your use of it is subject to your agreement with Google.
