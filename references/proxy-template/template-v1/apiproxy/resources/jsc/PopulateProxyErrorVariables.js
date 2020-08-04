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

// custom error handling here
switch (context.getVariable("fault.name")) {
  case "my.error":
    setFault(418, "Im a teapot", "418.99", "My Custom Error Message");
    break;
}
