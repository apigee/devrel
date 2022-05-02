# Apigee Templater Module

The logic for the proxy templating is contained in this Typescript module, which is designed to be extensible and customizable.  

## Installation

The **apigee-templater-module** can be added to any JS/TS project using NPM or yarn.

```sh
# Install Apigee-Templater-Module to do proxy templating
npm install apigee-templater-module
```

## Profiles

The module supports multiple profiles of plugin configurations. The profiles can provide custom configurations for any standardized proxy requirements.  The **default** and **bigquery** profiles are provided out-of-the-box for testing. Profiles can be injected when creating the **ApigeeGenerator** service object, or later by adjusting the **converterPlugins** and **profiles** collections.

## Converters

All template input files are sent through all converters to see who can convert the input into the default format.  Whichever converter plugin successfully returns a converted structure is then used for further processing. Each converter is responsible for checking the validity of the input, and deciding if a conversion can be done.

| Converter | Description |
| --------- | ----------- |
| lib/converters/json1.plugin.ts | Deserializes the default JSON format, default for all input files. |
| lib/converters/json2.plugin.ts | Deserializes an alternative custom JSON format and converts into the default format. |
| lib/openapiv3.yaml.plugin.ts | Deserializes OpenAPI v3 input files and returns the default format based on a subset of the fields.

## Plugins

After conversion of the input is complete, the plugins are responsible for converting different parts of the input into the final Apigee proxy bundle that is created. 

These plugins are in many cases quite basic, and meant to be customized and extended for specific project requirements.

| Plugin | Description |
| - | - |
| auth.apikey.plugin.ts | Converts any auth.apikey inputs into the Apigee format for checking API keys. |
| auth.sf.plugin.ts | Will add a shared flow callout to validate OAuth tokens |
| proxies.plugin.ts | Creates the proxy endpoint configurations in the bundle |
| targets.bigquery.plugin.ts | Checks the target configuration for either Query or Table properties, and if found adds the target configuration for retrieving BigQuery data and converting to a RESTful format. |
| targets.plugin.ts | Standard target support for HTTPS backend targets |
| traffic.quota.plugin.ts | Adds developer call quotas to the endpoint configuration |
| traffic.spikearrest.plugin.ts | Adds global spike arrest configuration to the endpoint configuration |


