/**
 * Copyright 2020 Google LLC
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
// get id_token expiry in seconds
var idTokenIdpExpiryInSeconds = context.getVariable('jwt.VJ-VerifyIdPIssuedIdToken.seconds_remaining');
var accessTokenIdpExpiryInSeconds = (context.getVariable('oidc.flow.expires_in') !== null)?parseInt(context.getVariable('oidc.flow.expires_in'), 10)*1000:1800*1000;

// set access_token expiry in milliseconds
var accessTokenExpiryInMilliSeconds = (idTokenIdpExpiryInSeconds !== null)?parseInt(idTokenIdpExpiryInSeconds, 10)*1000:accessTokenIdpExpiryInSeconds;

// set access_token expiry as a string in 'flow.idp.expires_in' variable
context.setVariable('flow.idp.expires_in',accessTokenExpiryInMilliSeconds.toString(10));