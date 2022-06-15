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

const code = "../../apiproxy/resources/jsc/responseMediation";

const runCode = () => {
  jest.resetModules();
  return require(code);
};

const originalResponse = {
  headers: {},
};

const responseWithExtraHeader = {
  headers: {
    "Content-Type": "text/plain",
    "x-foo": "bar"
  },
};

beforeEach(() => {
  global.context = {};
});

test("can add an extra header to the response", () => {
  global.context.getVariable = jest
    .fn()
    .mockReturnValueOnce(JSON.stringify(originalResponse));

  global.context.setVariable = jest.fn();

  runCode();

  expect(global.context.setVariable.mock.calls[0][0]).toBe("response.content");

  expect(
    JSON.parse(global.context.setVariable.mock.calls[0][1])
  ).toHaveProperty("headers.x-foo");
});