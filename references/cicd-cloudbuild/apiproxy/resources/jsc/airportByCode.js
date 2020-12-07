/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

const iataCode = context
  .getVariable("proxy.pathsuffix")
  .split("/")[2]
  .toUpperCase();

const allAirports = JSON.parse(context.getVariable("response.content"));
const matching = allAirports.find((a) => a.iata == iataCode);

if (matching) {
  context.setVariable("response.content", JSON.stringify(matching));
} else {
  setNotFoundError();
}

/**
 * Set the 404 Not Found error as a response
 */
function setNotFoundError() {
  const errorStatus = 404;
  const errorReason = "Not Found";
  const errrorContent = {
    errror: {
      errors: [
        {
          message: errorReason,
        },
      ],
      code: errorStatus,
      message: errorReason,
    },
  };

  context.setVariable("response.status.code", errorStatus);
  context.setVariable("response.reason.phrase", errorReason);
  context.setVariable("response.header.Content-Type", "application/json");
  context.setVariable("response.content", JSON.stringify(errrorContent));
}
