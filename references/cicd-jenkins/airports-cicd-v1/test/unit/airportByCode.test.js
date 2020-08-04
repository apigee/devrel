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
const assert = require("assert");
const mockFactory = require("./common/mockFactory");

const top10Airports = require("./common/testAirports");
const requireUncached = require("./common/requireUncached");
const jsFile = __dirname + "/../../apiproxy/resources/jsc/airportByCode.js";

describe("Airport By IATA Code", function () {
  describe("Code Match", function () {
    it("should return an airport object with matching IATA code", function () {
      const mocks = mockFactory.getMock();

      mocks.contextGetVariableMethod
        .withArgs("response.content")
        .returns(JSON.stringify(top10Airports));

      mocks.contextGetVariableMethod
        .withArgs("proxy.pathsuffix")
        .returns("/airports/ATL");

      let errorThrown = false;
      try {
        requireUncached(jsFile);
      } catch (e) {
        console.error(e);
        errorThrown = true;
      }
      assert(errorThrown === false, "ran without error");
      const spyResponse = mocks.contextSetVariableMethod.getCall(0).args[1];
      const response = JSON.parse(spyResponse);
      assert.equal(response.iata, "ATL", "Response has the correct IATA code");
    });

    it("should match airport codes case insensitively", function () {
      const mocks = mockFactory.getMock();
      mocks.contextGetVariableMethod
        .withArgs("response.content")
        .returns(JSON.stringify(top10Airports));
      mocks.contextGetVariableMethod
        .withArgs("proxy.pathsuffix")
        .returns("/airports/atl");

      let errorThrown = false;
      try {
        requireUncached(jsFile);
      } catch (e) {
        console.error(e);
        errorThrown = true;
      }
      assert(errorThrown === false, "ran without error");
      const spyResponse = mocks.contextSetVariableMethod.getCall(0).args[1];
      const response = JSON.parse(spyResponse);

      assert.equal(response.iata, "ATL", "Response has the correct IATA code");
    });
  });

  describe("No Code Match", function () {
    it("should return a 404 error code if no match is found.", function () {
      const mocks = mockFactory.getMock();
      mocks.contextGetVariableMethod
        .withArgs("response.content")
        .returns(JSON.stringify(top10Airports));
      mocks.contextGetVariableMethod
        .withArgs("proxy.pathsuffix")
        .returns("/airports/XXX");

      let errorThrown = false;
      try {
        requireUncached(jsFile);
      } catch (e) {
        console.error(e);
        errorThrown = true;
      }
      assert(errorThrown === false, "ran without error");

      assert(
        mocks.contextSetVariableMethod.calledWith("response.status.code", 404),
        "response.status.code set to 404"
      );
    });
  });
});
