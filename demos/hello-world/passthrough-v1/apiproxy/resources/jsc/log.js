/*
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

var logglyUrlScheme =
  context.getVariable('flow.apigee.originalRequest.header.X-Forwarded-Proto');
var logglyUrlDomain =
  context.getVariable('flow.apigee.originalRequest.header.Host');
var logglyBasePath = context.getVariable('proxy.basepath');
var logglyUrl = logglyUrlScheme + '://' + logglyUrlDomain + logglyBasePath + '/logs';
context.setVariable('debug.logglyUrl', logglyUrl);

var log = {
  org: context.getVariable('organization.name'),
  env: context.getVariable('environment.name'),
  api: context.getVariable('apiproxy.name'),
  request: {
    resource: context.getVariable('proxy.pathsuffix'),
    query: context.getVariable('flow.apigee.originalRequest.querystring'),
    verb: context.getVariable('flow.apigee.originalRequest.verb'),
  },
  error: {
    status: context.getVariable('flow.apigee.error.status'),
    code: context.getVariable('flow.apigee.error.code'),
    message: context.getVariable('flow.apigee.error.message'),
  },
};

var headers = {
  'Content-Type': 'application/json',
};

var logglyRequest =
  new Request(logglyUrl, 'POST', headers, JSON.stringify(log));
httpClient.send(logglyRequest);
