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

var isApigee = (typeof context !== "undefined");
var log = isApigee?print:console.log;

// ********************
// *** Schema Faker ***
// ********************

var defaultSeed = getRandomSeed();
var prng = splitmix32(defaultSeed);

function getRandomJSONSample(schema, spec, customSeed) {
  var seed = customSeed || defaultSeed;
  prng = splitmix32(seed);

  var sample = getRandomJSONSampleRecursive(schema, spec);
  return {
    "seed": seed,
    "sample": sample
  };
}

function getRandomYAMLSample(schema, spec, customSeed) {
  var result = getRandomJSONSample(schema, spec, customSeed);
  result.sample = toYAML(result.sample);
  return result;
}

function getRandomXMLSample(schema, spec, customSeed) {
  var seed = customSeed || defaultSeed;
  prng = splitmix32(seed);

  var result = getRandomXMLSampleRecursive(schema, spec, null,  "root", true);
  var sample = ""
  if (result instanceof XMLNode) {
    sample = result.toXMLString();
  }

  return {
    "seed": seed,
    "sample": sample
  };
}

function getRandomXMLSampleRecursive(schema, spec, type, name, wrap) {
  var result = [];
  var i;

  if (!schema) {
    return result;
  }

  if (schema.anyOf && schema.anyOf.length > 0) {
    return getRandomXMLSampleRecursive(schema.anyOf[getRandomInt(0, schema.anyOf.length - 1)], spec, null, name);
  }

  if (schema.oneOf && schema.oneOf.length > 0) {
    return getRandomXMLSampleRecursive(schema.oneOf[getSeededRandomInt(0, schema.anyOf.length - 1, defaultSeed)], spec, null, name);
  }

  if (schema.allOf && schema.allOf.length > 0 ) {
    var combinedSchema = {}
    for (i = 0; i < schema.allOf.length; i++) {
      combinedSchema = Object.assign(combinedSchema, schema.allOf[i])
    }

    return getRandomXMLSampleRecursive(combinedSchema, spec, null, name)
  }

  if (!type) {
    type = schema.type
  }

  if (type && Array.isArray(type) && type.length > 0 ) {
    var chosenType = getRandomInt(0, schema.type.length - 1);
    return getRandomXMLSampleRecursive(schema, spec, type[chosenType], name)
  }

  if (isRef(schema)) {
    var resolvedSchema = resolveRef(schema, spec);
    if (!resolvedSchema) {
      throw new Error("could not schema $ref '" + schema["$ref"]);
    }
    return getRandomXMLSampleRecursive(resolvedSchema, spec, null, name)
  }

  if (type && type === "object") {
    result = getXMLNodeFromSchema(name, schema);

    var properties = getRandomPropertiesFromSchema(schema);
    for (i = 0; i < properties.length; i++) {
      var propertyName = properties[i].name;
      var propertySchema = properties[i].schema;
      result.push(getRandomXMLSampleRecursive(propertySchema, spec, null, propertyName));
    }

    return result;
  }

  if (type === "array") {
    var childrenName = name;
    if (schema.xml && schema.xml["name"]) {
      childrenName = schema.xml["name"];
    }

    result = [];
    if (wrap || (schema.xml && schema.xml["wrapped"])) {
      result = getXMLNodeFromSchema(name, schema);
    }

    if (!schema.items) {
      return result;
    }

    var minItems = schema.minItems || 0
    var maxItems = schema.maxItems || getRandomInt(minItems + 1, minItems + 5);
    var length = getRandomInt(minItems, maxItems);

    for (i = 0; i < length; i++) {
      result.push(getRandomXMLSampleRecursive(schema.items, spec, null, childrenName))
    }

    return result;
  }

  if (type === "null") {
    result = getXMLNodeFromSchema(name, schema);
    result.data.attribute.push(new XMLNode("xsi", "", "xmlns", "http://www.w3.org/2001/XMLSchema-instance"));
    result.data.attribute.push(new XMLNode("nil", "", "xsi", "true"));
    return result;
  }

  if (type === "boolean") {
    result = getXMLNodeFromSchema(name, schema);
    result.data.value = getRandomBoolean();
  }

  if (type === "string") {
    result = getXMLNodeFromSchema(name, schema);
    result.data.value = getRandomStringFromSchema(schema);
    return result;
  }

  if (schema.const) {
    result = getXMLNodeFromSchema(name, schema);
    result.data.value = schema.const;
    return result;
  }

  if (type === "integer") {
    result = getXMLNodeFromSchema(name, schema);
    result.data.value = getRandomIntegerFromSchema(schema);
    return result;
  }

  if (type === "number") {
    result = getXMLNodeFromSchema(name, schema);
    result.data.value = getRandomNumberFromSchema(schema);
    return result;
  }

  return result;
}


function getRandomJSONSampleRecursive(schema, spec, type) {
  var result = {};
  var i;

  if (!schema) {
    return result
  }

  if (schema.anyOf && schema.anyOf.length > 0) {
    return getRandomJSONSampleRecursive(schema.anyOf[getRandomInt(0, schema.anyOf.length - 1)], spec);
  }

  if (schema.oneOf && schema.oneOf.length > 0) {
    return getRandomJSONSampleRecursive(schema.oneOf[getSeededRandomInt(0, schema.anyOf.length - 1, defaultSeed)], spec);
  }

  if (schema.allOf && schema.allOf.length > 0 ) {
    var combinedSchema = {}
    for (i = 0; i < schema.allOf.length; i++) {
      combinedSchema = Object.assign(combinedSchema, schema.allOf[i])
    }

    return getRandomJSONSampleRecursive(combinedSchema, spec)
  }

  if (!type) {
    type = schema.type
  }

  if (type && Array.isArray(type) && type.length > 0 ) {
    var chosenType = getRandomInt(0, schema.type.length - 1);
    return getRandomJSONSampleRecursive(schema, spec, type[chosenType])
  }

  if (isRef(schema)) {
    var resolvedSchema = resolveRef(schema, spec);
    if (!resolvedSchema) {
      throw new Error("could not resolve schema $ref '" + schema["$ref"] + "'");
    }
    return getRandomJSONSampleRecursive(resolvedSchema, spec)
  }

  if (type && type === "object") {
    result = {};
    var properties = getRandomPropertiesFromSchema(schema);
    for (i = 0; i < properties.length; i++) {
      var propertyName = properties[i].name;
      var propertySchema = properties[i].schema;
      result[propertyName] = getRandomJSONSampleRecursive(propertySchema, spec);
    }
    return result
  }

  if (type === "array") {
    result = [];
    if (!schema.items) {
      return result;
    }

    var minItems = schema.minItems || 0
    var maxItems = schema.maxItems || getRandomInt(minItems + 1, minItems + 5);

    var length = getRandomInt(minItems, maxItems);

    for (i = 0; i < length; i++) {
      result.push(getRandomJSONSampleRecursive(schema.items, spec))
    }
    return result;
  }

  if (type === "null") {
    return null
  }

  if (type === "boolean") {
    return getRandomBoolean();
  }

  if (type === "string") {
    return getRandomStringFromSchema(schema);
  }

  if (schema.const) {
    return schema.const
  }

  if (type === "integer") {
    return getRandomIntegerFromSchema(schema);
  }

  if (type === "number") {
    return getRandomNumberFromSchema(schema);
  }

  return result;
}


function getRandomStringFromSchema(schema) {
  if (schema.enum && schema.enum.length > 0) {
    return  schema.enum[getRandomInt(0, schema.enum.length - 1)];
  }

  if (schema.format && SUPPORTED_FORMATS[schema.format]) {
    return (SUPPORTED_FORMATS[schema.format])();
  }

  if (schema.pattern) {
    //not supported
  }

  if (!schema.minLength && !schema.maxLength) {
    return getRandomString(5,12);
  }

  var minLength = schema.minLength || 0;
  var maxLength = schema.maxLength || minLength + 1;

  return getRandomString(minLength, maxLength);
}

function getRandomIntegerFromSchema(schema) {
  if (!schema.minimum && !schema.maximum) {
    return getRandomInt(0, 65536);
  }

  var minimum = schema.minimum || 0;
  if (schema.exclusiveMinimum) {
    minimum = minimum + 1;
  }

  var maximum = schema.maximum || minimum + 1;
  if (schema.exclusiveMaximum) {
    maximum = maximum - 1;
  }

  if (schema.multipleOf) {
    return getRandomIntegerMultiple(minimum, maximum, schema.multipleOf);
  }

  return getRandomInt(minimum, maximum)
}

function getRandomNumberFromSchema(schema) {
  var isInteger = getRandomBoolean();
  if (isInteger) {
    return getRandomIntegerFromSchema(schema);
  }

  if (!schema.minimum && !schema.maximum) {
    return getRandomFloat(0, 65536);
  }

  var minimum = schema.minimum || 0.0;
  if (schema.exclusiveMinimum) {
    minimum = minimum + 1.0;
  }

  var maximum = schema.maximum || minimum + 1;
  if (schema.exclusiveMaximum) {
    maximum = maximum - 1.0;
  }

  if (schema.multipleOf) {
    return getRandomFloatMultiple(minimum, maximum, schema.multipleOf);
  }

  return getRandomFloat(minimum, maximum)
}


function getRandomPropertiesFromSchema(schema) {
  var i;
  var allProperties = [];
  if (schema.properties) {
    allProperties = Object.keys(schema.properties);
  }
  var remainingProperties = [];
  var mockedProperties = [];

  for (i = 0; i < allProperties.length; i++) {
    var propertyName = allProperties[i];
    if (schema.required && schema.required.indexOf(propertyName) >= 0) {
      mockedProperties.push({name: propertyName, schema: schema.properties[propertyName]});
    } else {
      remainingProperties.push(propertyName);
    }
  }

  var needPropertiesCount = 0;
  if (mockedProperties.length === 0 && remainingProperties.length > 0) {
    needPropertiesCount = getRandomInt(1, remainingProperties.length)
  } else if (mockedProperties.length > 0 && remainingProperties.length > 0)  {
    needPropertiesCount = getRandomInt(0, remainingProperties.length)
  }

  for (i = 0; i < needPropertiesCount; i++) {
    var randomElementIndex = getRandomInt(0, remainingProperties.length - 1);
    var randomElement = remainingProperties[randomElementIndex];
    remainingProperties.splice(randomElementIndex, 1);
    mockedProperties.push({name: randomElement, schema: schema.properties[randomElement]});
  }

  if (mockedProperties.length === 0) {
    //no properties were mocked, see if there are additional properties
    if (schema.additionalProperties && typeof schema.additionalProperties !== "boolean") {
      var additionalPropertiesCount = getRandomInt(1, 10);
      for (i = 0; i < additionalPropertiesCount; i++) {
        var additionalPropertyName = getRandomString(1, 10);
        mockedProperties.push({name: additionalPropertyName, schema: schema.additionalProperties});
      }
    }
  }

  return mockedProperties;
}

function getXMLNodeFromSchema(name, schema) {
  var node = new XMLNode(name);

  if (!schema.xml) {
    return node;
  }

  if (schema.xml.name) {
    node.data.name = schema.xml.name;
  }

  if (schema.xml.attribute) {
    node.data.attribute = true;
  }

  if (schema.xml.namespace) {
    node.data.namespace = schema.xml.namespace;
  }

  if (schema.xml.prefix) {
    node.data.prefix = schema.xml.prefix;
  }

  return node;
}

function XMLNode(name, namespace, prefix) {
  this.data = {
    "name": name,
    "namespace": namespace,
    "prefix": prefix,
    "children": [],
    "attributes": [],
    "attribute": false,
    "value": null,
  };
  return this;
}


XMLNode.prototype.push = function(node) {
  if (Array.isArray(node)) {
    for (var i = 0; i < node.length; i++) {
      this.push(node[i]);
    }
    return;
  }

  if (node.attribute) {
    this.data.attributes.push(node)
    return;
  }

  this.data.children.push(node);
}


XMLNode.prototype.toXMLString = function() {
  return getXMLNodeStringRecursive(this, 0);
}

function getXMLNodeStringRecursive(node, level) {
  var result = "";
  var i;

  if (node.data.attribute) {
    result = node.data.name + "=" + JSON.stringify(node.data.value);
    if (node.data.prefix) {
      result = node.data.prefix + ":" + result;
    }
    return result;
  }


  var indent = getIndentation(level);

  var elementAttributes = "";
  for (i = 0; i < node.data.attributes.length; i++) {
    elementAttributes += getXMLNodeStringRecursive(node.data.attributes[i], level + 1);
  }

  var elementName = (node.data.prefix?node.data.prefix + ":":"") + node.data.name;
  var elementNamespace =  (node.data.namespace? " xmlns=" + JSON.stringify(node.data.namespace):"")

  if (node.data.children.length === 0 &&  node.data.value === "") {
    //self closing element
    return indent + "<" + elementName + elementNamespace + elementAttributes + "/>";
  } else if (node.data.children.length === 0) {
    return indent + "<" + elementName + elementNamespace + elementAttributes + ">" + ((node.data.value === null)?"": node.data.value) + "</" + elementName + ">";

  }

  var header =  "<" + elementName + elementNamespace + elementAttributes + ">";
  var footer = "</" + elementName + ">";
  var children = "";

  for (i = 0; i < node.data.children.length; i++) {
    var childString = getXMLNodeStringRecursive(node.data.children[i], level + 1);
    if (children === "") {
      children = childString;
    } else {
      children += "\n" + childString;
    }
  }

  return indent + header + "\n" + children + "\n" + indent + footer;
}


function getIndentation(level) {
  var indent = "";
  for (var i = 0 ; i < level; i++) {
    indent += " ";
  }
  return indent;
}

function isRef(object) {
  return object && isString(object["$ref"]);
}

function resolveRef(object, doc) {
  if (!isRef(object)) {
    return object;
  }

  var resolved = resolveRefPath(object["$ref"], doc);
  if (isRef(resolved)) {
    return resolveRef(resolved, doc);
  }
  return resolved;
}

function resolveRefPath(path, doc) {
  var parts = path.split("/");

  var ref = parts[0];
  parts.shift();


  if (ref === "#") {
    return resolveRefPath(parts.join("/"), doc);
  }

  ref = ref.replace(/~0/g,"~");
  ref = ref.replace(/~1/, "/");

  var resolved = doc [ref];

  if (!resolved) {
    return null;
  }

  if (parts.length === 0) {
    return resolved;
  }

  return resolveRefPath(parts.join("/"), resolved);
}


function toYAML(data) {
  return toYAMLRecursive(data, 0);
}

function toYAMLRecursive(data, level) {
  var result = "";
  var indent = getIndentation(level);
  var i;

  //scalars
  if (data === undefined) {
    return "";
  } else if (data === null) {
    return "null"
  } else if (isString(data)) {
    return data;
  } else if(typeof data === "number" ) {
    return JSON.stringify(data);
  } else if (typeof data === "boolean" ) {
    return JSON.stringify(data)
  }


  if (Array.isArray(data)) {
    if (data.length === 0) {
      return "[]"
    }

    result = "";
    for (i = 0; i < data.length; i++) {
      if (level > 0 || i > 0) {
        result += "\n";
      }
      result += indent + "- " + toYAMLRecursive(data[i], level + 1)
    }
    return result;
  }

  if (typeof data === "object") {
    result = "";
    var properties = Object.keys(data);
    for (i = 0; i < properties.length; i++) {
      var propertyName = properties[i];
      if (level > 0 || i > 0) {
        result += "\n";
      }
      result += indent + propertyName + ": " + toYAMLRecursive(data[propertyName], level + 1);
    }
    return result;
  }

  return result;
}


var SUPPORTED_FORMATS = {
  "date-time": getRandomDateTime,
  "date": getRandomDate,
  "time": getRandomTime,
  "email": getRandomEmail,
  "uuid": getRandomUUID,
  "uri": getRandomURI,
  "hostname": getRandomHostname,
  "ipv4": getRandomIPv4,
  "ipv6": getRandomIPv6,
  "duration": getRandomDuration
};

function getRandomDateTime() {
  //date-time
  return getRandomDate() + "T" + getRandomTime();
}

function getRandomTime() {
  var hours = getRandomInt(0, 23); // Hours between 0 and 23
  var minutes = getRandomInt(0, 59); // Minutes between 0 and 59
  var seconds = getRandomInt(0, 59) // Seconds between 0 and 59

  // Ensure two-digit format
  var hoursStr = ("0" + hours).slice(-2);
  var minutesStr = ("0" + minutes).slice(-2);
  var secondsStr = ("0" + seconds).slice(-2);

  return hoursStr + ":" + minutesStr + ":" + secondsStr + "+00:00";
}

function getRandomDate() {
  //date
  var year = getRandomInt(1970, 2035) // Year between 1970 and 2024
  var month = getRandomInt(1, 12);
  var day = getRandomInt(1,30);

  // Ensure two-digit month and day
  var monthStr = ("0" + month).slice(-2);
  var dayStr = ("0" + day).slice(-2);

  return year + "-" + monthStr + "-" + dayStr;
}


function getRandomDuration() {
  //duration
  var duration = "P";

  // Randomly add years, months, and days
  if (getRandomBoolean()) {
    duration += getRandomInt(0, 9) + "Y"; // 0-9 years
  }
  if (getRandomBoolean()) {
    duration += getRandomInt(0, 11) + "M"; // 0-11 months
  }
  if (getRandomBoolean()) {
    duration += getRandomInt(0, 30) + "D"; // 0-30 days
  }

  // Randomly add time
  if (getRandomBoolean()) {
    duration += "T";
    if (getRandomBoolean()) {
      duration += getRandomInt(0, 23) + "H"; // 0-23 hours
    }
    if (getRandomBoolean()) {
      duration += getRandomInt(0, 59) + "M"; // 0-59 minutes
    }
    if (getRandomBoolean()) {
      duration += getRandomInt(0, 59)  + "S"; // 0-59 seconds
    }
  }

  if (duration === "P") {
    duration = "PT0S";
  }

  return duration;
}


function getRandomEmail() {
  //email
  const usernameLength = getRandomInt(5, 15);
  const domainLength = getRandomInt(3, 12);
  var i;

  const characters = "abcdefghijklmnopqrstuvwxyz0123456789";

  var username = "";
  for (i = 0; i < usernameLength; i++) {
    username += characters.charAt(Math.floor(getRandomFloat() * characters.length));
  }

  var domain = "";
  for (i = 0; i < domainLength; i++) {
    domain += characters.charAt(Math.floor(getRandomFloat() * characters.length));
  }

  const topLevelDomains = ["com", "net", "org", "io", "co.uk", "de"];
  const tld = topLevelDomains[Math.floor(getRandomFloat() * topLevelDomains.length)];

  return username + "@" + domain +"." + tld;
}

function getRandomHostname() {
  //hostname
  var hostnameLength = getRandomInt(5, 14)
  var characters = "abcdefghijklmnopqrstuvwxyz0123456789";

  var hostname = "";
  for (var i = 0; i < hostnameLength; i++) {
    hostname += characters.charAt(Math.floor(getRandomFloat() * characters.length));
  }

  return hostname;
}

function getRandomIPv4() {
  //ipv4
  var ipv4 = "";
  for (var i = 0; i < 4; i++) {
    ipv4 += Math.floor(getRandomFloat() * 256); // Generate number between 0 and 255
    if (i < 3) {
      ipv4 += ".";
    }
  }
  return ipv4;
}

function getRandomIPv6() {
  //ipv6
  var address = "";
  for (var i = 0; i < 8; i++) {
    var hexBlock = Math.floor(getRandomFloat() * 65536).toString(16);
    address += ("0000" + hexBlock).slice(-4);
    if (i < 7) {
      address += ":";
    }
  }
  return address;
}


function getRandomUUID() {
  //uuid
  var uuid = "";
  var characters = "abcdef0123456789";
  for (var i = 0; i < 36; i++) {
    if (i === 8 || i === 13 || i === 18 || i === 23) {
      uuid += "-";
    } else {
      uuid += characters.charAt(Math.floor(getRandomFloat() * characters.length));
    }
  }
  return uuid;
}

function getRandomURI() {
  //uri
  var scheme = "https"; // You can add more schemes if needed (e.g., "http", "ftp")
  var domainLength = getRandomInt(3, 12); // Domain between 3 and 12 characters
  var pathLength = getRandomInt(1, 10); // Path between 1 and 10 segments
  var characters = "abcdefghijklmnopqrstuvwxyz0123456789";

  var domain = "";
  for (var i = 0; i < domainLength; i++) {
    domain += characters.charAt(Math.floor(getRandomFloat() * characters.length));
  }

  var path = "";
  for (var j = 0; j < pathLength; j++) {
    var segmentLength = getRandomInt(1, 10); // Segment between 1 and 10 characters
    for (var k = 0; k < segmentLength; k++) {
      path += characters.charAt(Math.floor(getRandomFloat() * characters.length));
    }
    if (j < pathLength - 1) {
      path += "/";
    }
  }

  var topLevelDomains = ["com", "net", "org", "io", "co.uk", "de"];
  var tld = topLevelDomains[Math.floor(getRandomFloat() * topLevelDomains.length)];

  return scheme + "://" + domain + "." + tld + "/" + path;
}


function getRandomBoolean() {
  return getRandomFloat() < 0.5
}

function getRandomInt(min, max) {
  min = Math.ceil(min);
  max = Math.floor(max);
  return Math.floor(getRandomFloat() * (max - min + 1)) + min;
}

function getRandomFloatMultiple(min, max, multiple) {
  // Calculate the range of multiples that fit within min and max
  var adjustedMin = Math.ceil(min / multiple);
  var adjustedMax = Math.floor(max / multiple);

  // If there are no valid multiples, return null
  if (adjustedMax < adjustedMin) {
    return null;
  }

  // Generate a random integer between the adjusted min and max
  var randomMultiplier = Math.floor(getRandomFloat() * (adjustedMax - adjustedMin + 1)) + adjustedMin;

  // Return the result as a multiple of the given value
  return randomMultiplier * multiple;
}

function getRandomIntegerMultiple(min, max, multiple) {
  // Find the first integer that is a multiple of `multiple` and >= min
  var firstMultiple = Math.ceil(min / multiple) * multiple;

  // Find the last integer that is a multiple of `multiple` and <= max
  var lastMultiple = Math.floor(max / multiple) * multiple;

  // If there are no valid multiples in the range, return null
  if (firstMultiple > lastMultiple) {
    return null;
  }

  // Generate a list of valid integer multiples within the range
  var multiples = [];
  for (var i = firstMultiple; i <= lastMultiple; i += multiple) {
    // Only push `i` if it is an integer
    if (i % 1 === 0) {
      multiples.push(i);
    }
  }

  // If no valid integer multiples were found, return null
  if (multiples.length === 0) {
    return null;
  }

  // Pick a random integer from the list of valid multiples
  var randomIndex = Math.floor(getRandomFloat() * multiples.length);
  return multiples[randomIndex];
}

function getRandomFloat() {
  return prng();
}

function getSeededRandomInt(min, max, seed) {
  var x = Math.sin(seed) * 10000;
  return Math.floor((x - Math.floor(x)) * (max - min + 1)) + min;
}

function getRandomString(min, max) {
  var result = "";
  var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  var length = getRandomInt(min, max);
  for (var i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(getRandomFloat() * chars.length));
  }
  return result;
}

function splitmix32(a) {
  return function() {
    a |= 0;
    a = a + 0x9e3779b9 | 0;
    var t = a ^ a >>> 16;
    t = Math.imul(t, 0x21f0aaad);
    t = t ^ t >>> 15;
    t = Math.imul(t, 0x735a2d97);
    return ((t = t ^ t >>> 15) >>> 0) / 4294967296;
  }
}

function getRandomSeed() {
  return (Math.random()*4294967296)>>>0;
}

function setDefaultSeed(seed) {
  defaultSeed = seed;
  prng = splitmix32(seed);
}


// *************************
// **** Response Mocker ****
// *************************


var DEFAULT_STATUS = 200;
var DEFAULT_MEDIA_TYPE = "application/json";


function setMockedResponse(ctx) {
  var responseStatus;
  var responseContent;
  var responseHeaders = [];

  //read the path and verb
  var path = ctx.getVariable("proxy.pathsuffix");
  var verb = ctx.getVariable("request.verb").toLowerCase();

  //ignore OPTIONS verb, used for CORS
  if (verb === "options") {
    setResponse(ctx, 200, [], "");
    return;
  }

  //read the spec
  var spec_json = ctx.getVariable("spec_json");
  var spec = parseSpec(spec_json);


  //read the headers
  var accept = ctx.getVariable("request.header.accept.values.string");
  var mockStatus = ctx.getVariable("request.header.mock-status");
  var mockExample = ctx.getVariable("request.header.mock-example");
  var mockSeed = ctx.getVariable("request.header.mock-seed") || null;
  mockSeed = mockSeed? parseInt(mockSeed): getRandomSeed();
  if (mockSeed) {
    setDefaultSeed(mockSeed);
  }
  responseHeaders.push(["mock-seed", mockSeed.toString()]);

  var mockFuzz = ctx.getVariable("request.header.mock-fuzz") || null ;
  mockFuzz = mockFuzz? mockFuzz === "true" || mockFuzz === true : false;


  // choose operation (based on verb and path)
  var operation = getOperation(spec, verb, path);
  if (!operation) {
    setErrorResponse(ctx, 500,"no operation found for verb: " + verb + ", path: " + path);
    return;
  }
  var operationId = operation["operationId"];


  //fi no responses available, error out
  if (!operation["responses"]) {
    setErrorResponse(ctx, 500,"no responses found for operationId: " + operationId);
    return;
  }

  // choose response (based on status code)
  var responseInfo = getResponse(operation, mockStatus, mockFuzz);
  if (!responseInfo) {
    //there are no listed responses, default to 200 with empty body
    setResponse(ctx, 200, responseHeaders, "");
    responseHeaders.push(["mock-warning", "no responses found operationId '" + operationId+"'"]);
    return;
  }

  responseStatus = responseInfo.status;


  // choose content (based on media type)
  var contentInfo = getResponseContent(responseInfo.response, mockStatus, accept, mockFuzz);
  if (!contentInfo) {
    //there are no available content, default to empty body
    setResponse(ctx, responseStatus, responseHeaders, "");
    responseHeaders.push(["mock-warning", "no response content found for '" + operationId+"', status: '" + responseStatus + "'"]);
    return;
  }

  if (contentInfo.warning) {
    responseHeaders.push(["mock-warning", contentInfo.warning])
  }

  responseHeaders.push(["Content-Type", contentInfo.mediaType]);


  // choose or generate example
  var chosenPath = path  + "." + verb + ".responses." + responseStatus + ".content." + contentInfo.mediaType;
  var exampleInfo = getResponseExample(spec, chosenPath, contentInfo, {
    mockStatus: mockStatus,
    accept: accept,
    mockExample: mockExample,
    mockFuzz: mockFuzz});

  if (exampleInfo.warning) {
    responseHeaders.push(["mock-warning", exampleInfo.warning])
  }

  if (!isString(exampleInfo.example)) {
    responseContent = getPrettyJSON(exampleInfo.example);
  } else {
    responseContent = exampleInfo.example;
  }

  setResponse(ctx, responseStatus, responseHeaders, responseContent);
}

function isString(obj) {
  return (Object.prototype.toString.call(obj) === '[object String]');
}

function getOperation(spec, verb, path) {
  if (!spec.paths) {
    return null;
  }

  var matchingPathTemplates = [];

  for (var pathTemplate in spec.paths) {
    if (pathMatches(path, pathTemplate)) {
      matchingPathTemplates.push(pathTemplate);
    }
  }

  if (matchingPathTemplates.length === 0) {
    return null;
  }

  //if more than one path match, choose the one with the least number placeholders
  if (matchingPathTemplates.length === 1) {
    return spec.paths[matchingPathTemplates[0]][verb];
  }

  var pathTemplatesInfo = [];
  for (var i = 0; i < matchingPathTemplates.length; i++) {
    pathTemplatesInfo.push({
      "pathTemplate": matchingPathTemplates[i],
      "placeHoldersCount": (matchingPathTemplates[i].match(/\{[^}]+}/g) || []).length
    });
  }

  //sort number of placeholders
  pathTemplatesInfo.sort(function(a, b) {
    return a.placeHoldersCount - b.placeHoldersCount;
  });

  //the path template with the least number of placeholders is the most concrete
  return spec.paths[pathTemplatesInfo[0].pathTemplate][verb];
}

function getResponseContent(response, mockStatus, accept, mockFuzz) {

  if (!response.content || Object.keys(response.content).length === 0) {
    return null;
  }

  var supportedMedias = Object.keys(response.content);

  if (accept) {
    //user requested specific media type
    var responseMediaType = getBestMediaType(accept, supportedMedias);
    if (!responseMediaType && mockStatus) {
      //user specifically asked for a status and a media type that is not available
      throw new HTTPError(400, "requested media type '" + accept + "' not supported, valid ones are: " + supportedMedias.join(","), []);
    }

    if (!responseMediaType && !mockStatus) {
      // requested media type was not available
      // user specifically requested a media type, but did not care about the status code
      // instead of returning an error, fall back to default, or random one
      if (supportedMedias.indexOf(DEFAULT_MEDIA_TYPE) >= 0) {
        return {
          mediaType: DEFAULT_MEDIA_TYPE,
          content: response.content[DEFAULT_MEDIA_TYPE],
          warning: "requested media type '" + accept + "' not supported, default one chosen"
        }
      } else {
        var fallbackMediaType = supportedMedias[getRandomInt(0, supportedMedias.length - 1)];
        return {
          mediaType: fallbackMediaType,
          content: response.content[fallbackMediaType],
          warning: "requested media type '" + accept + "' not supported, random one chosen"
        }
      }
    }

    return {
      mediaType: responseMediaType,
      content: response.content[responseMediaType],
    }
  } else  if (mockFuzz) {
    //user requested a random media type
    var randomMediaType = supportedMedias[getRandomInt(0, supportedMedias.length - 1)];
    return {
      mediaType: randomMediaType,
      content: response.content[randomMediaType],
    }
  } else {
    //user did not pass Accept or Mock-Fuzz header
    if (supportedMedias.indexOf(DEFAULT_MEDIA_TYPE) >= 0) {
      return {
        mediaType: DEFAULT_MEDIA_TYPE,
        content: response.content[DEFAULT_MEDIA_TYPE],
      }
    } else {
      var randomMediaType = supportedMedias[getRandomInt(0, supportedMedias.length - 1)];
      return {
        mediaType: randomMediaType,
        content: response.content[randomMediaType],
      }
    }

  }
}

function getResponse(operation, mockStatus, mockFuzz) {

  var responseStatus;
  var responsesByStatus = operation["responses"];
  var supportedStatuses = Object.keys(responsesByStatus);

  if (supportedStatuses.length === 0) {
    return null;
  }

  if (mockStatus) {
    //user requested specific status code using Mock-Status: true
    responseStatus = getBestResponseStatus(mockStatus, supportedStatuses);
    if (!responseStatus) {
      //user requested specific status, but it's not available
      throw new HTTPError(400, "requested status '" + mockStatus + "' not found, valid ones are: " + supportedStatuses.join(","), [])
    }

    if (responseStatus === "default") {
      return getRandomDefaultResponse(operation);
    }

    return {
      status: responseStatus.toString(),
      response: operation["responses"][responseStatus.toString()]
    }
  } else if (mockFuzz) {
    //user requested random status code using Mock-Fuzz: true
    return getRandomResponse(operation);
  } else {
    //neither Mock-Fuzz or Mock-Status is used
    if (supportedStatuses.indexOf(DEFAULT_STATUS.toString()) >= 0) {
      return {
        status: DEFAULT_STATUS.toString(),
        response: operation["responses"][DEFAULT_STATUS.toString()]
      }
    }

    return getRandomResponse(operation);
  }
}

function getRandomResponse(operation) {
  var responseStatus;
  var responsesByStatus = operation["responses"];
  var supportedStatuses = Object.keys(responsesByStatus);

  if (supportedStatuses.length === 0 && supportedStatuses[0] === "default") {
    //there is only one status available, and it's the default one
    return {
      status: DEFAULT_STATUS.toString(),
      response: operation["responses"]["default"]
    }
  }

  responseStatus = supportedStatuses[getRandomInt(0, supportedStatuses.length - 1)];

  if (responseStatus === "default") {
    //we randomly picked the "default"
    // the spec says that this is used for status that is not already in the list
    // so, randomly pick a status from the list below until we find a suitable one
    // (by suitable, it means it's not already in the supported list)
    return getRandomDefaultResponse(operation);
  }

  return {
    status: responseStatus,
    response: operation["responses"][responseStatus]
  }
}

function getRandomDefaultResponse(operation) {
  var responsesByStatus = operation["responses"];
  var supportedStatuses = Object.keys(responsesByStatus);

  if (supportedStatuses.indexOf(DEFAULT_STATUS.toString()) < 0 ) {
    //if HTTP 200 can be used, then use
    return {
      status: DEFAULT_STATUS.toString(),
      response: operation["responses"]["default"]
    }
  }

  //otherwise, take a random pick
  var statusOptions = [400, 404, 401, 403, 500];
  var randomPick;

  while(statusOptions.length > 0) {
    var randomIndex = getRandomInt(0, statusOptions.length - 1);
    var randomElement = statusOptions[randomIndex];
    statusOptions.splice(randomIndex, 1);

    if (supportedStatuses.indexOf(randomElement.toString()) < 0) {
      randomPick = randomElement;
      break;
    }
  }

  if (!randomPick) {
    //none of the options worked, so give up and use HTTP 420 ¯\_(ツ)_/¯
    randomPick = 420;
  }

  return {
    status: randomPick.toString(),
    response: operation["responses"]["default"]
  }
}

function getResponseExample(spec, contentPath, contentInfo, options) {
  if (!contentInfo.content) {
    return {
      example: "",
      warning: "no content found for " + contentPath
    }
  }

  var mediaType = contentInfo.mediaType;
  var schema = contentInfo.content.schema;
  var example = contentInfo.content.example;
  var examples = contentInfo.content.examples

  if (options.mockFuzz) {
    if (!schema) {
      if (options.mockStatus && options.accept) {
        throw new HTTPError(400,
          "cannot fuzz response, no schema found for " + contentPath +
          ", try different values for the 'mock-status' and 'accept' headers", []);
      }

      if (options.mockStatus && !options.accept) {
        throw new HTTPError(400,
          "cannot fuzz response, no schema found for " + contentPath +
          ", try different value for the 'accept' header", []);
      }

      if (!options.mockStatus && !options.accept) {
        throw new HTTPError(400,
          "cannot fuzz response, no schema found for " + contentPath +
          ", try setting the 'mock-status' and 'accept' header", []);
      }
    }

    //fuzz the response
    return fuzzExampleFromSchema(mediaType, spec, schema);
  } else if (example) {
    return {
      example: example
    }
  } else if(examples && Object.keys(examples).length > 0) {
    //map of examples, this was introduced in the OAS3 specification

    var exampleName;
    var exampleObject;
    var warning;

    var exampleNames = Object.keys(examples);

    if (options.mockExample) {
      if (exampleNames.indexOf(options.mockExample) >= 0) {
        //user requested example is available use that
        exampleName = options.mockExample;
        exampleObject = examples[exampleName];
      } else {
        //user requested example is not available
        if (options.mockStatus && options.accept) {
          throw new HTTPError(400,  "requested example '" + options.mockExample + "' not found, valid ones are: " + exampleNames.join(","), []);
        }

        //user requested example not found, pick a random one
        exampleName = exampleNames[getRandomInt(0, exampleNames.length - 1)];
        exampleObject = examples[exampleName];
        warning = "requested example '" + options.mockExample + "' not not found, random one chosen"; //FIXME: add available ones
      }
    } else {
      //user did not request any specific example, pick a random example
      exampleName = exampleNames[getRandomInt(0, exampleNames.length - 1)];
      exampleObject = examples[exampleName];
    }

    if (isRef(exampleObject)) {
      exampleObject = resolveRef(exampleObject, spec);
      if (!exampleObject) {
        throw new HTTPError(500, "could not resolve $ref '" + exampleObject["$ref"] + "' for '" + exampleName + "' example", []);
      }
    }

    return {
      example: exampleObject.value || "",
      warning: warning
    }
  } else if (schema && schema.example) {
    return {
      example: schema.example,
    }
  } else if (schema) {
    return fuzzExampleFromSchema(mediaType, spec, schema);
  }

  return {
    example: "",
    warning: "no example or schema found for " + contentPath
  }
}

function  fuzzExampleFromSchema(mediaType, spec, schema) {
  var example = "";
  if (mediaType.indexOf("json") >= 0) {
    example = getRandomJSONSample(schema, spec).sample;
    example = getPrettyJSON(example);
  } else if (mediaType.indexOf("yaml") >= 0) {
    example = getRandomYAMLSample(schema, spec).sample;
  } else if (mediaType.indexOf("xml" >= 0)) {
    example = getRandomXMLSample(schema, spec).sample;
  }

  return {
    example: example
  }
}

function HTTPError(status, message, headers) {
  this.status = status;
  this.message = message;
  this.headers = headers;
  return this;
}


function pathMatches(path, pathTemplate) {
  // Escape special regex characters in the template
  var escapedTemplate = pathTemplate.replace(/[-[\]()*+?.,\/\\^$|#\s]/g, '\\$&');

  // Replace placeholders with a regex that matches at least one character
  var regexPattern = escapedTemplate.replace(/\{[^}]+}/g, '[^/]+');

  // Create a regular expression from the pattern
  var regex = new RegExp('^' + regexPattern + '$');

  // Test the string against the regex
  return regex.test(path);
}


function parseSpec(json) {
  var parsed_spec = {};
  if (!isString(json) || json === "") {
    throw new Error("could not find OpenAPI spec, set spec_json flow variable");
  }

  try {
    parsed_spec = JSON.parse(json);
  } catch(e) {
    throw new Error("could not parse spec. error: " + e.message)
  }
  return parsed_spec
}

function setResponse(ctx, status, headers, content) {
  ctx.setVariable("response.status.code", status.toString());

  if (Array.isArray(headers)) {
    //group headers by name (for multi-value headers)
    var headerMap = {}
    for (var i = 0; i < headers.length; i++) {
      var hName = headers[i][0];
      var hValue = headers[i][1];
      if (!headerMap[hName]) {
        headerMap[hName] = [];
      }
      headerMap[hName].push(hValue);
    }

    for (var header in headerMap) {
      var headerValues = headerMap[header];
      if (headerValues.length === 1) {
        ctx.setVariable("response.header." + header.toLowerCase(), headerMap[header][0]);
        continue;
      }

      ctx.setVariable("response.header." + header.toLowerCase() + "-Count", headerMap[header].length);
      for (var j = 0; j < headerValues.length; j++) {
        ctx.setVariable("response.header." + header.toLowerCase() + "-" + j, headerMap[header][j]);
      }
    }
  }
  ctx.setVariable("response.content", content)
}

function setErrorResponse(ctx, status, error) {
  var responseBody = {
    status: status
  };

  if (isString(error)) {
    responseBody.error = error
  }

  if (error.status) {
    status = error.status
  }

  if (error.message) {
    responseBody.error =  error.message;
  }

  if (error.stack) {
    responseBody.stack = error.stack;
  }

  var headers = [];
  if (error.headers) {
    headers = headers.concat(error.headers);
  }

  headers.push(['Content-Type', 'application/json']);

  setResponse(ctx, status, [], getPrettyJSON(responseBody));
}

function getPrettyJSON(value) {
  return JSON.stringify(value, null, 2);
}


function mediaTypesMatch(mediaTypeA, mediaTypeB) {

  if (mediaTypeA === mediaTypeB) {
    //if simple equality check passes, exit early
    return true;
  }

  //otherwise parse them, and check for match
  var aParts = mediaTypeA.split("/");
  var bParts = mediaTypeB.split("/");

  var aType = aParts[0];
  var aSubType = null;
  if (aParts.length > 1) {
    aSubType = aParts[1];
  }

  var bType = bParts[0];
  var bSubType = null;
  if (bParts.length > 1) {
    bSubType = bParts[1];
  }

  if (!(aType === "*" || bType === "*" || aType === bType)) {
    //main type does not match
    return false;
  }

  if (aSubType === "*" || bSubType === "*" || aSubType === bSubType) {
    //subtype matches exactly, exit early, or with wildcard
    return true;
  }

  if (!aSubType || !bSubType) {
    //one of the subtypes is not defined, nothing to compare
    return false;
  }

  return false;
}

function getBestResponseStatus(requestedStatus, supportedStatuses) {
  if (requestedStatus && supportedStatuses.indexOf(requestedStatus.toString()) >= 0 ) {
    return requestedStatus;
  } else if (supportedStatuses.length === 1  && supportedStatuses[0] === "default") {
    //only the default status is available
    return "default";
  }
  return null;
}

function getBestMediaType(requestedMedia, supportedMedias) {
  var i,j;

  if (!isString(requestedMedia) || requestedMedia.length === 0) {
    if (supportedMedias.indexOf(DEFAULT_MEDIA_TYPE) >= 0) {
      return DEFAULT_MEDIA_TYPE;
    } else {
      return supportedMedias[getRandomInt(0, supportedMedias.length - 1)]
    }
  }

  var requestedMediaParts = requestedMedia.replace(/\s+/g,"").split(",");
  var requestedMediaInfos = [];
  for (i = 0; i < requestedMediaParts.length; i++) {
    var part = requestedMediaParts[i];
    var infoParts = part.split(";");

    var mediaType = infoParts[0];
    var mediaQ = 1;

    if (infoParts.length > 1) {
      var attrParts = infoParts[1].split(",");
      for (j = 0; j < attrParts.length; j++) {
        var fieldParts = attrParts[j].split("=");
        if (fieldParts.length < 2) {
          continue;
        }
        var fieldName = fieldParts[0].trim();
        var fieldValue = fieldParts[1].trim();
        if (fieldName === "q") {
          mediaQ = parseFloat(fieldValue);
          break;
        }
      }
    }

    requestedMediaInfos.push({
      "mediaType": mediaType,
      "mediaQ": mediaQ
    });
  }

  requestedMediaInfos.sort(function (a, b) {
    return b.mediaQ - a.mediaQ;
  })


  for (i = 0; i < requestedMediaParts.length; i++) {
    for (j = 0; j < supportedMedias.length; j++) {
      var currRequestedMedia = requestedMediaInfos[i].mediaType;
      var curSupportedMedia = supportedMedias[j];
      if (mediaTypesMatch(currRequestedMedia, curSupportedMedia)) {
        return curSupportedMedia;
      }
    }
  }

  return null;
}


function main(ctx) {
  try {
    setMockedResponse(ctx);
  } catch(e) {
    log("error.message: " + e.message);
    log("error.stack:\n" + e.stack);
    setErrorResponse(ctx,500, e);
  }
}

if (isApigee) {
  main(context);
} else {
  module.exports = {
    "getRandomJSONSample": getRandomJSONSample,
    "getRandomXMLSample": getRandomXMLSample,
    "setMockedResponse": setMockedResponse,
    "getRandomYAMLSample": getRandomYAMLSample,
    "getBestMediaType": getBestMediaType,
    "pathMatches": pathMatches,
    "getOperation": getOperation
  };
}