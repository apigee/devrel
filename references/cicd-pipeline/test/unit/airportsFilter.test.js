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
const jsFile = __dirname + "/../../apiproxy/resources/jsc/airportsFilter.js";

describe("Airports Filter", function () {
  describe("No Filter", function () {
    it("should return all airports if no filter is set", function () {
      const mocks = mockFactory.getMock();

      mocks.contextGetVariableMethod
        .withArgs("response.content")
        .returns(JSON.stringify(top10Airports));

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

      assert.equal(response.length, 10, "Return all elements");
    });
  });

  describe("Country Filter", function () {
    it("should only return airports in the specified country", function () {
      const mocks = mockFactory.getMock();
      mocks.contextGetVariableMethod
        .withArgs("response.content")
        .returns(JSON.stringify(top10Airports));
      mocks.contextGetVariableMethod
        .withArgs("request.queryparam.country")
        .returns("japan");

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
      assert.equal(response.length, 1, "Return only the matching elements");

      assert(
        response.every((a) => a.country == "Japan"),
        "Only contain airports in the specified country."
      );
    });
  });

  describe("Size Limit Filter", function () {
    it("should only return a limited count of airports", function () {
      const mocks = mockFactory.getMock();
      mocks.contextGetVariableMethod
        .withArgs("response.content")
        .returns(JSON.stringify(top10Airports));
      mocks.contextGetVariableMethod
        .withArgs("request.queryparam.limit")
        .returns("5");

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

      assert(response.length <= 5, "Return an array of size <= limit");
    });
  });
});
