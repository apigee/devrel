# Apigee API Proxy Endpoint Unifier

Apigee X and hybrid have a limitation of hosting up to 5 Proxy Endpoints per API Proxy. Apigee Edge has no such limitation.
The objective of this tool is to take a proxy bundle and intelligently convert its proxy endpoints into logically
grouped conditional flows, in order to stay within the Proxy Endpoint limit.

## Disclaimer
This is not an officially supported Google product.

## Prerequisites
* `python3`
* Please install the required Python dependencies
```
    python3 -m pip install -r requirements.txt
```
* Please fill in `input.properties`
```
    [common]
    input_apis=apis                                     # Folder Containing exported & unzipped Proxy Bundles
    processed_apis=transformed                          # Folder to export transformed Proxies to 
    proxy_bundle_directory=transformed_zipped_bundles   # Folder to export transformed Proxies Bundles (zip) to 
    proxy_endpoint_count=4                              # Number of Proxy Endpoints to retain while transforming (1-5)
    debug=false                                         # Flag to export debug logs

    [validate]
    enabled=true                                        # Flag to enable proxy validation
    gcp_project_id=xxx-xxx-xxx                          # Apigee Project for proxy validation
```

* If enabling validation, please run the following command to authenticate against Apigee APIs:

```
    export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)
```


## Usage
Run the script as below
```
python3 main.py
```

## Limitations
* This tool does not currently handle the resources within API proxies.

## Copyright

Copyright 2023 Google LLC. This software is provided as-is, without warranty or representation for any use or purpose. Your use of it is subject to your agreement with Google.
