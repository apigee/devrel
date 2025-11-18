/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * Parses error message to extract code and message
 * @param {Object} error - Error object
 * @returns {Object} Parsed error with code and message
 */
export default async function errorHandler(error) {
  try {
    const errorDetails = JSON.parse(error.message);
    const code = errorDetails.error.code;
    const message = errorDetails.error.message || 'Unknown Error';
    return { code, message };
  } catch {
    return { code: 'Unknown', message: error.message || 'Unknown Error' };
  }
}
