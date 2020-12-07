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

const allAirports = JSON.parse(context.getVariable("response.content"));

var countryParam = context.getVariable("request.queryparam.country");
if (countryParam) {
  countryParam = countryParam.toLowerCase();
}

const limitParam = context.getVariable("request.queryparam.limit");

var filtered = allAirports;

if (countryParam && countryParam.length > 0) {
  filtered = filtered.filter(
    (airport) => airport.country.toLowerCase() === countryParam
  );
}

if (limitParam && limitParam > 0) {
  filtered = filtered.slice(0, parseInt(limitParam, 10));
}

context.setVariable("response.content", JSON.stringify(filtered));
