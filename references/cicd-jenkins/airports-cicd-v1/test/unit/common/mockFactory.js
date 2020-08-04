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

const sinon = require("sinon");

let contextGetVariableMethod;
let contextSetVariableMethod;

beforeEach(function () {
  global.context = {
    getVariable: function (s) {},
    setVariable: function (s, a) {},
  };
  contextGetVariableMethod = sinon.stub(global.context, "getVariable");
  contextSetVariableMethod = sinon.spy(global.context, "setVariable");
});

afterEach(function () {
  contextGetVariableMethod.restore();
  contextSetVariableMethod.restore();
});

exports.getMock = function () {
  return {
    contextGetVariableMethod: contextGetVariableMethod,
    contextSetVariableMethod: contextSetVariableMethod,
  };
};
