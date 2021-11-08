/**
 * Copyright 2021 Google LLC
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
// PKCE: get initial code challenge - code challenge method is 'S256'
var codeChallenge = context.getVariable('oauthv2authcode.OA2-GetOriginalStateAttributes.code_challenge');

// get code verifier from form params
var codeVerifier = context.getVariable('request.formparam.code_verifier');

// create a new SHA-256 object
var sha256 = crypto.getSHA256();

// update thw SHA-256 object
sha256.update(codeVerifier);

// return the SHA-256 object as a base64Url string
var hashedCodeVerifier = sha256.digest64().replace(/=+$/, '')
// replace characters according to base64url specifications
.replace(/\+/g, '-')
.replace(/\//g, '_');

// is PKCE code verified or not ? yes => true, no => false
var isPKCECodeVerified = ( hashedCodeVerifier === codeChallenge )?true:false;

// set context variable 'oidc.flow.isPKCECodeVerified'
context.setVariable('oidc.flow.isPKCECodeVerified',isPKCECodeVerified);