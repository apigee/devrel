#Custom MGMT API Endpoint proxy for Apigee Edge module

Customers may want to integrate their own IDP systems with Apigee.
The API Keys and access tokens are managed outside of Apigee. To enable this
flow we typically have to extend Apigee Drupal modules and write extensions
to handle these.

This module lets you replace the default MGMT endpoints with a proxy endpoint.
Customers can write their login in Apigee proxies and handle the /apps endpoint.

To install this module:
 1. Copy the contents of this folder and place it in the 
 `modules/custom/apigee_edge_custom_mgmt_api_proxy` folder of your drupal 
 installation.
2. Enable the `Apigee Mgmt API proxy override` module from the extend menu




## Disclaimer

This repository and its contents are not an official Google product.
