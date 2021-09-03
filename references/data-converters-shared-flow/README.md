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

The type of data conversion is determined by **`dataconverter.type`**, and currently supports these values:

```xml
<!--Converts OData responses to simple REST -->
<Parameter name="dataconverter.type">odata2rest</Parameter> 
<!--Converts BigQuery responses to simple REST -->
<Parameter name="dataconverter.type">bigquery2rest</Parameter>
<!--Converts Firestore responses to simple REST -->
<Parameter name="dataconverter.type">firestore2rest</Parameter>
```

The **`dataconverter.resource`** should contain the name of the resource object, which will be used to format the JSON output.  This can easily be extracted from the URL path of the API using the [`ExtractVariables`](https://cloud.google.com/apigee/docs/api-platform/reference/policies/extract-variables-policy#uripathelement) policy (so for example extracting `orders` as the resource name from the URL `https://api.example.com/orderservice/{orders})` into the `resource` variable, and which can be passed to the shared flow as in the example above.

The **`dataconvert.input`** parameter should contain the source data either in the `odata`, `bigquery`, or `firestore` formats.  The `response.content` variable is commonly used for this after calling the source systems API for data.

The result of the conversion is returned in the **`dataconverter.output`** parameter, which can be assigned to the response with an **AssignMesssage** policy like this:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<AssignMessage continueOnError="false" enabled="true" name="Set-Response">
    <DisplayName>Set-Response</DisplayName>
    <Properties/>
    <Set>
        <Payload contentType="application/json">{dataconverter.output}</Payload>
    </Set>
    <IgnoreUnresolvedVariables>false</IgnoreUnresolvedVariables>
    <AssignTo createNew="false" transport="http" type="response"/>
</AssignMessage>
```

## Extending
The shared flow default flow has 3 policies to do the conversions, which are optionally triggered depending on the value of `dataconverter.type`.  

```xml
<SharedFlow name="default">
    <Step>
        <Condition>dataconverter.type = "odata"</Condition>
        <Name>convert-odata</Name>
    </Step>
    <Step>
        <Condition>dataconverter.type = "bigquery"</Condition>
        <Name>convert-bigquery</Name>
    </Step>
    <Step>
        <Condition>dataconverter.type = "firestore"</Condition>
        <Name>convert-firestore</Name>
    </Step>
</SharedFlow>
```

You can easily extend this with further conversions as needed, so adding any other specific formats that you need converted into simple JSON.  Also the conversions here are pretty simple, and ignore some things like nested objects, but which could be added if needed for specific use-cases.
