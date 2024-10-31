/*
 *  Copyright 2024 Google LLC
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

const request = require('supertest');



const fs = require('fs');
const { expect, test, describe, beforeEach } = require('@jest/globals');
const {setMockedResponse} = require("../apiproxy/resources/jsc/response-mocker");
const APIGEE_X_HOSTNAME= process.env.APIGEE_X_HOSTNAME;
const BASE_PATH = `/mock/v3/petstore`


let PROXY_URL;

describe("response-mocker-int", () => {

  beforeEach(() => {
    expect(APIGEE_X_HOSTNAME).toBeDefined();
    PROXY_URL=`https://${APIGEE_X_HOSTNAME}${BASE_PATH}`
  });

  test('get /pet/findByStatus (mock-status: null, accept: null) | pre-defined example/json', async () => {
    const response = await request(PROXY_URL).get('/pet/findByStatus');

    expect(response.status).toBe(200);
    expect(parseInt(response.headers['mock-seed'])).toBeGreaterThan(0);
    expect(response.headers["content-type"]).toBe("application/json");
    expect(response.body.length).toBe(3); //pre-defined example has 3 items
  });

  test("get /pet/findByStatus (seeded, mock-status: 400, accept: application/json) | random example", async () => {
    let seed = 741831438;

    const response = await request(PROXY_URL)
      .get("/pet/findByStatus")
      .set("mock-seed", seed.toString())
      .set("mock-status", "400")
      .set("accept", "application/json")

    expect(response.status).toBe(400);
    expect(parseInt(response.headers['mock-seed'])).toEqual(seed);
    expect(response.headers["content-type"]).toBe("application/json");
    expect(response.body).toEqual({
      "type": "FpqoyPpqk",
      "message": "np42DB",
      "code": 25302
    });
  });


  test("get /pet/findByTags (seeded, mock-status: null, accept: null) | random example/json", async () => {

    let seed = 4108554714;

    const response = await request(PROXY_URL)
      .get("/pet/findByTags")
      .set("mock-seed", seed.toString());


    expect(response.status).toBe(200);
    expect(parseInt(response.headers['mock-seed'])).toEqual(seed);
    expect(response.headers["content-type"]).toBe("application/json");
    expect(response.body).toEqual([
      {
        "name": "CZXJyk9l7W",
        "photoUrls": [
          "4CEixuTUa"
        ],
        "id": 812,
        "status": "pending",
        "category": {
          "name": "yDtXJUe6BU"
        }
      },
      {
        "name": "bYekBj4S12M5",
        "photoUrls": [
          "XsknZJ"
        ],
        "category": {
          "name": "KUcYv2o"
        },
        "status": "sold"
      }
    ]);

  });


  test("get /pet/findByTags (seeded, mock-status: 200, accept: */*) | random example/xml", async () => {
    let seed = 4108554714;

    const response = await request(PROXY_URL)
      .get("/pet/findByTags")
      .set("accept", "*/*")
      .set("mock-status", "200")
      .set("mock-seed", seed.toString());

    expect(response.status).toBe(200);
    expect(parseInt(response.headers['mock-seed'])).toEqual(seed);
    expect(response.headers["content-type"]).toBe("application/xml");
    expect(response.text).toEqual(`
<root>
 <pet>
  <name>CZXJyk9l7W</name>
  <photoUrls>
   <photoUrl>4CEixuTUa</photoUrl>
  </photoUrls>
  <id>812</id>
  <status>pending</status>
  <category>
   <name>yDtXJUe6BU</name>
  </category>
 </pet>
 <pet>
  <name>bYekBj4S12M5</name>
  <photoUrls>
   <photoUrl>XsknZJ</photoUrl>
  </photoUrls>
  <category>
   <name>KUcYv2o</name>
  </category>
  <status>sold</status>
 </pet>
</root>`.trim());
  });

});


