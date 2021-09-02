# Common Data Converters - Shared Flow

This shared flow can be used to convert between some common data response formats (currently **OData**, **BigQuery**, and **Firestore**) and clean, JSON objects that are ideal to return as response objects of RESTful APIs. 

## Prerequisites
In order to deploy this shared flow from your local machine, you must have `gcloud`, `zip` and `jq` installed.

## How to deploy
To deploy this shared flow to your `Apigee X` org:

```sh
export APIGEE_X_ORG=<your Apigee X org>
export APIGEE_X_ENV=<your Apigee X environment>
./deploy.sh
```

## How to test
You can test the javascript logic used in this sharedflow by executing this:

```sh
npm install
npm test
```

The tests for an example OData, BigQuery and Firestore payload are in the `test` directory.

## How to use
Simply set the following variables to configure how and what this sharedflow converts from your API proxy in the **FlowCallout** policy:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<FlowCallout continueOnError="false" enabled="true" name="Convert-Response">
    <DisplayName>Convert-Response</DisplayName>
    <FaultRules/>
    <SharedFlowBundle>SF-Data-Converters</SharedFlowBundle>
    <Parameters>
        <Parameter name="dataconverter.type">odata2rest</Parameter>
        <Parameter name="dataconverter.resource">{resource}</Parameter>
        <Parameter name="dataconverter.input">{response.content}</Parameter>
    </Parameters>
</FlowCallout>
```
The type of data conversion is determined by `dataconverter.type`, and currently supports these values:

```xml
<!--Converts OData responses to simple REST -->
<Parameter name="dataconverter.type">odata2rest</Parameter> 
<!--Converts BigQuery responses to simple REST -->
<Parameter name="dataconverter.type">bigquery2rest</Parameter>
<!--Converts Firestore responses to simple REST -->
<Parameter name="dataconverter.type">firestore2rest</Parameter>
```

The result of the conversion is returned in the `dataconverter.output` parameter, which can be assigned to the response with an **AssignMesssage** policy like this:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<AssignMessage continueOnError="false" enabled="true" name="Set-Response">
    <DisplayName>Set-Response</DisplayName>
    <Properties/>
    <Set>
        <Payload>{dataconverter.output}</Payload>
    </Set>
    <IgnoreUnresolvedVariables>true</IgnoreUnresolvedVariables>
    <AssignTo createNew="false" transport="http" type="response"/>
</AssignMessage>
```

