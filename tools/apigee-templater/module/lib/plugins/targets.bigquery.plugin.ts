/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Handlebars from 'handlebars'
import { ApigeeTemplatePlugin, PlugInResult, proxyEndpoint } from '../interfaces'

/**
 * Plugin for generating targets
 * @date 2/14/2022 - 8:15:26 AM
 *
 * @export
 * @class TargetsPlugin
 * @typedef {TargetsPlugin}
 * @implements {ApigeeTemplatePlugin}
 */
export class TargetsBigQueryPlugin implements ApigeeTemplatePlugin {

  targetSnippet = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<TargetEndpoint name="{{targetName}}">
    <PreFlow name="PreFlow">
      <Request>
        <Step>
          <Name>SetQuery</Name>
        </Step>
      </Request>
      <Response/>
    </PreFlow>
    <Flows/>
    <PostFlow name="PostFlow">
      <Request/>
      <Response>
        <Step>
          <Name>ConvertResponse</Name>
        </Step>
      </Response>
    </PostFlow>
    <HTTPTargetConnection>
      <Authentication>
        <GoogleAccessToken>
          <Scopes>
            <Scope>https://www.googleapis.com/auth/bigquery</Scope>
          </Scopes>
          <LifetimeInSeconds>3600</LifetimeInSeconds>
        </GoogleAccessToken>
      </Authentication>      
      <URL>https://bigquery.googleapis.com/bigquery/v2/projects/{{project}}/queries</URL>
    </HTTPTargetConnection>
</TargetEndpoint>`;

  jsPolicySnippet = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Javascript continueOnError="false" enabled="true" timeLimit="200" name="{{name}}">
    <DisplayName>{{name}}</DisplayName>
    <Properties/>
    <ResourceURL>jsc://{{name}}.js</ResourceURL>
</Javascript>`;

  jsQuerySnippet = `context.targetRequest.method='POST';
context.targetRequest.headers['Content-Type']='application/json';

context.setVariable("target.copy.pathsuffix", false);

var filter = "";
var orderBy = "";
var pageSize = "";
var pageToken = "";

for(var queryParam in request.queryParams){
    if (queryParam == "filter") {
        filter = "WHERE " + context.getVariable("request.queryparam." + queryParam);
    }
    else if (queryParam == "orderBy") {
        orderBy = "ORDER BY " + context.getVariable("request.queryparam." + queryParam);
    }
    else if (queryParam == "pageSize") {
        var tempPageSize =  context.getVariable("request.queryparam." + queryParam);
        pageSize = "LIMIT " + tempPageSize;
        context.setVariable("bq.pageSize", tempPageSize);
    }
    else if (queryParam == "pageToken") {
        var tempPageToken =  context.getVariable("request.queryparam." + queryParam);
        pageToken = "OFFSET " + parseInt(context.getVariable("request.queryparam.pageSize")) * (parseInt(tempPageToken) - 1);
        context.setVariable("bq.pageToken", tempPageToken);
    }
}

var query = "{{query}}";
var table = "{{table}}";

if (table)
  query = "SELECT * FROM " + table + " %filter% %orderBy% %pageSize% %pageToken%";

query = query.replace("%filter%", filter);
query = query.replace("%orderBy%", orderBy);
query = query.replace("%pageSize%", pageSize);
query = query.replace("%pageToken%", pageToken);

context.targetRequest.body = '' +
    '{' + 
    '   "query": "' + query + '",' +            
    '   "useLegacySql": false,' +
    '   "maxResults": 1000' +
    '}';`;

  jsResponseSnippet = `var bqResponse = context.getVariable("response.content");
var pageSize = context.getVariable("bq.pageSize");
var pageToken = context.getVariable("bq.pageToken");
var entityName = context.getVariable("proxy.basepath").replace("/", "");

var responseObject = {};

responseObject[entityName] = ConvertBigQueryResponse(JSON.parse(bqResponse));

if (pageToken) {
    responseObject["next_page_token"] = parseInt(pageToken) + 1;
}
else {
    responseObject["next_page_token"] = 2;
}

context.setVariable("response.content", JSON.stringify(responseObject));

function ConvertBigQueryResponse(inputObject) {
    var result = [];
    for (var rowKey in inputObject.rows) {
        var row = inputObject.rows[rowKey];
        var newRow = {};
        for (var valueKey in row.f) {
            var value = row.f[valueKey];
            newRow[inputObject.schema.fields[valueKey].name] = value.v;
        }
        result.push(newRow);
    }
    return result;
}`;

  targetTemplate = Handlebars.compile(this.targetSnippet);
  jsPolicyTemplate = Handlebars.compile(this.jsPolicySnippet);
  jsQueryTemplate = Handlebars.compile(this.jsQuerySnippet);
  jsResponseTemplate = Handlebars.compile(this.jsResponseSnippet);

  /**
   * Templates the targets configurations
   * @date 2/14/2022 - 8:15:57 AM
   *
   * @param {proxyEndpoint} inputConfig
   * @param {Map<string, object>} processingVars
   * @return {Promise<PlugInResult>}
   */
  applyTemplate(inputConfig: proxyEndpoint): Promise<PlugInResult> {
    return new Promise((resolve) => {
      const fileResult: PlugInResult = new PlugInResult()

      let project = process.env.PROJECT;

      if (inputConfig.parameters && inputConfig.parameters.PROJECT) {
        project = inputConfig.parameters.PROJECT;
      }

      if (inputConfig.target) {
        fileResult.files = [
          {
            path: '/targets/' + inputConfig.target.name + '.xml',
            contents: this.targetTemplate({ targetName: inputConfig.target.name, project: project })
          },
          {
            path: '/policies/SetQuery.xml',
            contents: this.jsPolicyTemplate({ name: "SetQuery" })
          },
          {
            path: '/resources/jsc/SetQuery.js',
            contents: this.jsQueryTemplate({ query: inputConfig.target.query, table: inputConfig.target.table })
          },
          {
            path: '/policies/ConvertResponse.xml',
            contents: this.jsPolicyTemplate({ name: "ConvertResponse" })
          },
          {
            path: '/resources/jsc/ConvertResponse.js',
            contents: this.jsResponseTemplate({})
          }
        ]
      }

      resolve(fileResult)
    })
  }
}
