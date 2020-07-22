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

const code = '../../apiproxy/resources/jsc/responseMediation';

const runCode = () => {
  jest.resetModules();
  return require(code);
};

const responseWithTraceId = {
  headers: {
    'X-Amzn-Trace-Id': 'blah blah',
  },
};

const responseWithoutTraceId = {
  headers: {
    'Content-Type': 'text/plain',
  },
};

beforeEach(() => {
  global.context = {};
});

test('can remove trace id from response', () => {
  global.context.getVariable =
    jest.fn().mockReturnValueOnce(JSON.stringify(responseWithTraceId));

  global.context.setVariable = jest.fn();

  runCode();

  expect(global.context.setVariable.mock.calls[0][0])
      .toBe('response.content');

  expect(JSON.parse(global.context.setVariable.mock.calls[0][1]))
      .not
      .toHaveProperty('X-Amzn-Trace.Id');
});

test('no change in responses where there is no sensitive properties', () => {
  global.context.getVariable =
    jest.fn().mockReturnValueOnce(JSON.stringify(responseWithoutTraceId));

  global.context.setVariable = jest.fn();

  runCode();

  expect(global.context.setVariable.mock.calls[0][0])
      .toBe('response.content');

  expect(JSON.parse(global.context.setVariable.mock.calls[0][1]))
      .toStrictEqual(responseWithoutTraceId);
});
