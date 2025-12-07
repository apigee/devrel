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

import crypto from 'crypto';

export default function md5(data) {
  if (data === null || typeof data === 'undefined') {
    return null;
  }

  if (data instanceof Buffer) {
    return crypto.createHash('md5').update(data).digest('hex');  
  }

  if (typeof data === 'object') {
    return crypto.createHash('md5').update(JSON.stringify(data)).digest('hex');
  }

  return crypto.createHash('md5').update(data).digest('hex');
}
