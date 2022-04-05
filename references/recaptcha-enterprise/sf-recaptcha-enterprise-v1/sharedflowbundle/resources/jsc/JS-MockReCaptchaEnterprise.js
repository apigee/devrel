/**
  Copyright 2022 Google LLC
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
      https://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

/**
 * Set date and time.
 * @return {string}
 */
function setDateAndTime() {
    var today = new Date();
    return today.toISOString();
}

// Get reCAPTCHA context variables
var reCaptchaToken = context.getVariable('flow.recaptcha.token');
var gcpProjectId = context.getVariable('flow.recaptcha.gcp-projectid');
var siteKey = context.getVariable('flow.recaptcha.sitekey');

// Set token validity and risk score
var token = reCaptchaToken.substring("X-RECAPTCHA-TOKEN-".length);
var riskScore = parseFloat(token);
var isTokenValid = (!isNaN(riskScore) && riskScore >= 0 && riskScore <= 1)?true:false;

// Set the reCAPTCHA assessment response
var assessmentResp = {
  name: "projects/" + gcpProjectId + "/assessments/1234567890",
  event: {
    token: reCaptchaToken,
    siteKey: siteKey,
    userAgent: "",
    userIpAddress: "",
    expectedAction: "",
    hashedAccountId: ""
  },
  riskAnalysis: {
    reasons: []
  },
  tokenProperties: {
    valid: isTokenValid,
    invalidReason: "INVALID_REASON_UNSPECIFIED",
    hostname: "recaptcha.example.com",
    action: "homepage",
    createTime: setDateAndTime()
  }
};

// If tokenn is valid, then add the risk score
if( isTokenValid ) {
   assessmentResp.riskAnalysis.score = riskScore;
}

// Set the assessmenet response context variable
context.setVariable('recaptchaAssessmentResponse',JSON.stringify(assessmentResp));

