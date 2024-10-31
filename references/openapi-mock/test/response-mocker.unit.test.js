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

const fs = require('fs');
const { setMockedResponse , getBestMediaType, pathMatches, getOperation } = require("../apiproxy/resources/jsc/response-mocker.cjs");
const { expect, test, describe } = require('@jest/globals');

class MockContext {
  constructor(init) {
    this.data = init || {}
  }

  setVariable(name, value) {
    this.data[name] = value
  }

  getVariable(name) {
    return this.data[name]
  }
}

const petStoreSpec = fs.readFileSync('./apiproxy/resources/oas/spec.json', 'utf8');

describe("response-mocker-unit", () => {
  test("get /pet/findByStatus (mock-status: null, accept: null) | pre-defined example/json", () => {

    let ctx = new MockContext({
      "request.verb": "GET",
      "proxy.pathsuffix": "/pet/findByStatus",
      "request.header.accept.values.string": "application/json",
      "spec_json": petStoreSpec
    });

    setMockedResponse(ctx);

    expect(parseInt(ctx.getVariable("response.status.code"))).toBe( 200);
    expect(parseInt(ctx.getVariable("response.header.mock-seed"))).toBeGreaterThan(0);
    expect(ctx.getVariable("response.header.content-type")).toBe("application/json");
    expect(JSON.parse(ctx.getVariable("response.content"))).toHaveLength(3); //pre-defined example has 3 items
  })

  test("get /pet/findByStatus (seeded, mock-status: 400, accept: application/json) | random example", () => {
    let seed = 741831438;
    let ctx = new MockContext({
      "request.verb": "GET",
      "proxy.pathsuffix": "/pet/findByStatus",
      "request.header.mock-seed": seed,
      "request.header.mock-status": 400,
      "request.header.accept.values.string": "application/json",
      "spec_json": petStoreSpec
    });

    setMockedResponse(ctx);

    expect(parseInt(ctx.getVariable("response.status.code"))).toBe( 400);
    expect(parseInt(ctx.getVariable("response.header.mock-seed"))).toEqual(seed);
    expect(ctx.getVariable("response.header.content-type")).toBe("application/json");
    expect(ctx.getVariable("response.content")).toBeDefined();
    expect(JSON.parse(ctx.getVariable("response.content"))).toEqual({
        "type": "FpqoyPpqk",
        "message": "np42DB",
        "code": 25302
      });
  })


  test("get /pet/findByStatus (mock-status: 400, accept: application/json) | random example/json", () => {

    let ctx = new MockContext({
      "request.verb": "GET",
      "proxy.pathsuffix": "/pet/findByStatus",
      "request.header.mock-status": "400",
      "request.header.accept.values.string": "application/json",
      "spec_json": petStoreSpec
    });

    setMockedResponse(ctx)

    expect(parseInt(ctx.getVariable("response.status.code"))).toBe(400);
    expect(parseInt(ctx.getVariable("response.header.mock-seed"))).toBeGreaterThan(0);
    expect(ctx.getVariable("response.header.content-type")).toBe("application/json");
    expect(ctx.getVariable("response.content")).toBeDefined()
    expect(Object.keys(JSON.parse(ctx.getVariable("response.content"))).length).toBeGreaterThan(0);
  })

  test("get /pet/findByTags (mock-status: null, accept: null) | random example/json", () => {
    let ctx = new MockContext({
      "request.verb": "GET",
      "proxy.pathsuffix": "/pet/findByTags",
      "spec_json": petStoreSpec
    });

    setMockedResponse(ctx);

    expect(parseInt(ctx.getVariable("response.status.code"))).toBe(200);
    expect(parseInt(ctx.getVariable("response.header.mock-seed"))).toBeGreaterThan(0);

    expect(ctx.getVariable("response.content")).toBeDefined();
    expect(ctx.getVariable("response.header.content-type")).toBe("application/json");
    expect(Array.isArray(JSON.parse(ctx.getVariable("response.content")))).toBeTruthy();

  });

  test("get /pet/findByTags (mock-status: null, accept: application/xml) | random example/xml ", () => {

    let ctx = new MockContext({
      "request.verb": "GET",
      "proxy.pathsuffix": "/pet/findByTags",
      "request.header.accept.values.string": "application/xml",
      "spec_json": petStoreSpec
    });

    setMockedResponse(ctx);

    expect(parseInt(ctx.getVariable("response.status.code"))).toBe(200);
    expect(parseInt(ctx.getVariable("response.header.mock-seed"))).toBeGreaterThan(0);
    expect(ctx.getVariable("response.header.content-type")).toBe("application/xml");
    expect(ctx.getVariable("response.content")).toMatch(/^<root>[\s\S]*<\/root>$/gm)
  });

  test("get /pet/findByTags (seeded, mock-status: null, accept: null) | random example/json", () => {
    let seed = 4108554714;
    let ctx = new MockContext({
      "request.verb": "GET",
      "proxy.pathsuffix": "/pet/findByTags",
      "request.header.mock-seed": seed,
      "spec_json": petStoreSpec,
    })

    setMockedResponse(ctx);

    expect(parseInt(ctx.getVariable("response.status.code"))).toBe(200);
    expect(parseInt(ctx.getVariable("response.header.mock-seed"))).toEqual(seed);
    expect(ctx.getVariable("response.header.content-type")).toBe("application/json");
    expect(JSON.parse(ctx.getVariable("response.content"))).toEqual([
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


  test("get /pet/findByTags (seeded, mock-status: 200, accept: */*) | random example/xml", () => {
    let seed = 4108554714;
    let ctx = new MockContext({
      "request.verb": "GET",
      "proxy.pathsuffix": "/pet/findByTags",
      "request.header.accept.values.string": "*/*",
      "request.header.mock-seed": seed,
      "request.header.mock-status": 200,
      "spec_json": petStoreSpec,
    })

    setMockedResponse(ctx);

    expect(parseInt(ctx.getVariable("response.status.code"))).toBe(200);
    expect(ctx.getVariable("response.header.content-type")).toBe("application/xml");
    expect(parseInt(ctx.getVariable("response.header.mock-seed"))).toEqual(seed);
    expect(ctx.getVariable("response.content")).toEqual(`
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

  test("get /pet/1 (seeded, mock-status: 200, accept: */*) | random example/xml", () => {
    let seed = 2706157134;
    let ctx = new MockContext({
      "request.verb": "GET",
      "proxy.pathsuffix": "/pet/1",
      "request.header.accept.values.string": "*/*",
      "request.header.mock-seed": seed,
      "request.header.mock-status": 200,
      "spec_json": petStoreSpec,
    })

    setMockedResponse(ctx);

    expect(parseInt(ctx.getVariable("response.status.code"))).toBe(200);
    expect(ctx.getVariable("response.header.content-type")).toBe("application/xml");
    expect(parseInt(ctx.getVariable("response.header.mock-seed"))).toEqual(seed);
    expect(ctx.getVariable("response.content")).toEqual(`
<pet>
 <name>S8guw</name>
 <photoUrls>
  <photoUrl>h6Ume1</photoUrl>
 </photoUrls>
</pet>`.trim());
  });

  test("get /store/inventory (seeded, mock-status: 200, accept: */*) | random example/xml", () => {
    let seed = 1880333565;
    let ctx = new MockContext({
      "request.verb": "GET",
      "proxy.pathsuffix": "/store/inventory",
      "request.header.accept.values.string": "application/xml",
      "request.header.mock-seed": seed,
      "request.header.mock-status": 200,
      "spec_json": petStoreSpec,
    })

    setMockedResponse(ctx);

    expect(parseInt(ctx.getVariable("response.status.code"))).toBe(200);
    expect(ctx.getVariable("response.header.content-type")).toBe("application/xml");
    expect(parseInt(ctx.getVariable("response.header.mock-seed"))).toEqual(seed);
    expect(ctx.getVariable("response.content")).toEqual(`
<root>
 <a5>54185</a5>
 <rrZgzAkN>30392</rrZgzAkN>
 <Z1>52264</Z1>
 <Cgfbg>48409</Cgfbg>
</root>`.trim());
  });

  test("get /store/inventory (seeded, mock-status: 200, accept: */*) | random example/json", () => {
    let seed = 1880333565;
    let ctx = new MockContext({
      "request.verb": "GET",
      "proxy.pathsuffix": "/store/inventory",
      "request.header.accept.values.string": "application/json",
      "request.header.mock-seed": seed,
      "request.header.mock-status": 200,
      "spec_json": petStoreSpec,
    })

    setMockedResponse(ctx);

    expect(parseInt(ctx.getVariable("response.status.code"))).toBe(200);
    expect(ctx.getVariable("response.header.content-type")).toBe("application/json");
    expect(parseInt(ctx.getVariable("response.header.mock-seed"))).toEqual(seed);
    expect(JSON.parse(ctx.getVariable("response.content"))).toEqual({
      "a5": 54185,
      "rrZgzAkN": 30392,
      "Z1": 52264,
      "Cgfbg": 48409
    });
  });

  test("post /user (seeded, mock-status: 200, accept: application/json) | random example/json", () => {
    let seed = 2432976933;
    let ctx = new MockContext({
      "request.verb": "POST",
      "proxy.pathsuffix": "/user",
      "request.header.accept.values.string": "application/json",
      "request.header.mock-seed": seed,
      "request.header.mock-status": 200,
      "spec_json": petStoreSpec,
    })

    setMockedResponse(ctx);

    expect(parseInt(ctx.getVariable("response.status.code"))).toBe(200);
    expect(ctx.getVariable("response.header.content-type")).toBe("application/json");
    expect(parseInt(ctx.getVariable("response.header.mock-seed"))).toEqual(seed);
    expect(JSON.parse(ctx.getVariable("response.content"))).toEqual({
      "username": "Pxpb5h0Cgi",
      "lastName": "clSrhqZB",
      "firstName": "rk3Vowkw7NV3"
    });
  });


  test("post /user/createWithList (seeded, mock-status: null, accept: null) | random example/json", () => {
    let seed = 2432976933;
    let ctx = new MockContext({
      "request.verb": "POST",
      "proxy.pathsuffix": "/user/createWithList",
      "request.header.mock-seed": seed,
      "spec_json": petStoreSpec,
    })

    setMockedResponse(ctx);

    expect(parseInt(ctx.getVariable("response.status.code"))).toBe(200);
    expect(ctx.getVariable("response.header.content-type")).toBe("application/json");
    expect(parseInt(ctx.getVariable("response.header.mock-seed"))).toEqual(seed);
    expect(JSON.parse(ctx.getVariable("response.content"))).toEqual({
      "username": "Pxpb5h0Cgi",
      "lastName": "clSrhqZB",
      "firstName": "rk3Vowkw7NV3"
    });
  });

  test("post /user/createWithList (seeded, mock-status: default, accept: null) | default ", () => {
    let seed = 2432976933;

    let ctx = new MockContext({
      "request.verb": "POST",
      "proxy.pathsuffix": "/user/createWithList",
      "request.header.mock-status": "default",
      "request.header.mock-seed": seed,
      "spec_json": petStoreSpec,
    })

    setMockedResponse(ctx);

    expect(parseInt(ctx.getVariable("response.status.code"))).toBe(404);
    expect(ctx.getVariable("response.header.content-type")).not.toBeDefined();
    expect(parseInt(ctx.getVariable("response.header.mock-seed"))).toEqual(seed);
    expect(ctx.getVariable("response.content")).toEqual("");
  });




  test("get /user/logout (seeded, mock-status: null, accept: null) | default", () => {
    let ctx = new MockContext({
      "request.verb": "GET",
      "proxy.pathsuffix": "/user/logout",
      "spec_json": petStoreSpec,
    })

    setMockedResponse(ctx);

    expect(parseInt(ctx.getVariable("response.status.code"))).toBe(200);
    expect(ctx.getVariable("response.header.content-type")).not.toBeDefined();
    expect(ctx.getVariable("response.content")).toEqual("");
  });


  test( "ranked media match", () => {
    let requestedMedia = "application/json;q=0.8,application/yaml;q=0.5,application/xml;q=1"
    let supportedMedia = ["application/json", "application/yaml", "application/xml",];
    let mediaType = getBestMediaType(requestedMedia, supportedMedia);
    expect(mediaType).toBe("application/xml")
  });


  test( "specific media match", () => {
    let requestedMedia = "application/yaml"
    let supportedMedia = ["application/json", "application/yaml", "application/xml",];
    let mediaType = getBestMediaType(requestedMedia, supportedMedia);
    expect(mediaType).toBe("application/yaml")
  });

  test( "wildcard media match", () => {
    let requestedMedia = "*/*"
    let supportedMedia = ["application/json", "application/xml",];
    let mediaType = getBestMediaType(requestedMedia, supportedMedia);
    expect(mediaType).toBe("application/json")
  });

  test( "complex media-type match", () => {
    let requestedMedia = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
    let supportedMedia = ["application/json", "application/xml"];
    let mediaType = getBestMediaType(requestedMedia, supportedMedia);
    expect(mediaType).toBe("application/xml")
  });


  test( "root path match", () => {
    expect(pathMatches("/", "/")).toBe(true);
  });

  test( "simple path match", () => {
    expect(pathMatches("/foo", "/foo")).toBe(true);
  });

  test( "simple path match (negative)", () => {
    expect(pathMatches("/foo", "/bar")).toBe(false);
  });

  test( "multi-segment path match", () => {
    expect(pathMatches("/foo/bar/fizz/buzz", "/foo/bar/fizz/buzz")).toBe(true);
  });

  test( "multi-segment path match (negative)", () => {
    expect(pathMatches("/foo/bar/fizz/fizz", "/foo/bar/fizz/buzz")).toBe(false);
  });

  test( "simple template", () => {
    expect(pathMatches("/foo", "/{id}")).toBe(true);
  });

  test( "simple template (negative)", () => {
    expect(pathMatches("/foo/bar/buzz", "/{id}")).toBe(false);
  });

  test( "complex template path patch (negative)", () => {
    expect(pathMatches("/foo/1/bar", "/foo/hello.{id}.world/bar")).toBe(false);
  });

  test( "complex template path patch (positive)", () => {
    expect(pathMatches("/foo/hello.1.world/bar", "/foo/hello.{id}.world/bar")).toBe(true);
  });

  test( "simple template cross-segment path (negative)", () => {
    expect(pathMatches("/foo/1/2", "/{id}")).toBe(false);
  });

  test( "simple template cross-segment path (negative)", () => {
    expect(pathMatches("/foo/1/2", "/{id}")).toBe(false);
  });

  test( "complex template cross-segment path (negative)", () => {
    expect(pathMatches("/foo/1/2", "/foo/{id}")).toBe(false);
  });

  test( "simple operation lookup", () => {
    var spec = {
      paths: {
        "/":{
          get: "op1"
        },
        "/foo/{id}": {
          get: "op2"
        }
      }
    }

    expect(getOperation(spec, "get", "/foo/1")).toBe("op2");
  });

  test( "simple operation lookup (negative)", () => {
    var spec = {
      paths: {
        "/":{
          get: "op1"
        },
        "/foo/{id}": {
          get: "op2"
        }
      }
    }

    expect(getOperation(spec, "get", "/foo/bar/buzz")).toBe(null);
    expect(getOperation(spec, "get", "/foo")).toBe(null);
  });

  test( "most concrete operation lookup", () => {
    var spec = {
      paths: {
        "/":{
          get: "op1"
        },
        "/{id1}/{id2}": {
          get: "op2"
        },
        "/foo/{id}": {
          get: "op3"
        },
        "/{id}/1": {
          get: "op4"
        }
      }
    }

    expect(getOperation(spec, "get", "/foo/1")).toBe("op3");
  });
});


