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

/**
 * Sets required error variables
 *
 * @param {number} status - HTTP Status Code
 * @param {string} phrase - HTTP Reason Phrase
 * @param {string} code - Payload Error Code
 * @param {string} message - Payload Error Message
 * @param {string} url - Payload Info URL
 */
function setFault(status, phrase, code, message, url) {
  context.setVariable("custom.error.code", code);
  context.setVariable("custom.error.message", message);
  context.setVariable(
    "custom.error.url",
    url ? url : "https://developers.example.com"
  );
  context.setVariable("custom.error.status", status);
  context.setVariable("custom.error.phrase", phrase);
}

switch (context.getVariable("fault.name")) {
  case "access_token_expired":
  case "invalid_access_token":
  case "InvalidAccessToken":
    setFault(
      401,
      "Unauthorized",
      "401.99",
      "Unauthorized - Token Invalid or Expired"
    );
    break;
  case "ErrorResponseCode":
    switch (context.getVariable("response.status.code")) {
      case "400":
        setFault(400, "Bad Request", "400.99", "Invalid Request");
        break;
      case "404":
        setFault(404, "Resource Not Found", "404.99", "Resource Not Found");
        break;
    }
}

if (!context.getVariable("custom.error.code")) {
  setFault(500, "Internal Server Error", "500.99", "Internal Server Error");
}
