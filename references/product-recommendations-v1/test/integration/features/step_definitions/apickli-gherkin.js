/* jslint node: true */
'use strict';

var prettyJson = require('prettyjson');

var stepContext = {};

module.exports = function () {
    this.registerHandler('BeforeScenario', function (scenario, callback) {
        stepContext.scenario = scenario.getName;
        callback();
    });

    this.registerHandler('BeforeStep', function(step, callback) {
        stepContext.step = step.getName;
        callback();
    });

    this.Given(/^I set (.*) header to (.*)$/, function (headerName, headerValue, callback) {
        this.apickli.addRequestHeader(headerName, headerValue);
        callback();
    });

    this.Given(/^I set headers to$/, function(headers, callback) {
        this.apickli.setHeaders(headers.hashes());
        callback();
    });

    this.Given(/^I set body to (.*)$/, function (bodyValue, callback) {
        this.apickli.setRequestBody(bodyValue);
        callback();
    });

    this.Given(/^I pipe contents of file (.*) to body$/, function (file, callback) {
        this.apickli.pipeFileContentsToRequestBody(file, function (error) {
            if (error) {
                callback(new Error(error));
            }

            callback();
        });
    });

    this.Given(/^I set query parameters to$/, function(queryParameters, callback) {
        this.apickli.setQueryParameters(queryParameters.hashes());
        callback();
    });

    this.Given(/^I have basic authentication credentials (.*) and (.*)$/, function (username, password, callback) {
        this.apickli.addHttpBasicAuthorizationHeader(username, password);
        callback();
    });

    this.When(/^I GET (.*)$/, function (resource, callback) {
        this.apickli.get(resource, function (error, response) {
            if (error) {
                callback(new Error(error));
            }

            callback();
        });
    });

    this.When(/^I POST to (.*)$/, function (resource, callback) {
        this.apickli.post(resource, function (error, response) {
            if (error) {
                callback(new Error(error));
            }

            callback();
        });
    });

    this.When(/^I PUT (.*)$/, function (resource, callback) {
        this.apickli.put(resource, function (error, response) {
            if (error) {
                callback(new Error(error));
            }

            callback();
        });
    });

    this.When(/^I DELETE (.*)$/, function (resource, callback) {
        this.apickli.delete(resource, function (error, response) {
            if (error) {
                callback(new Error(error));
            }

            callback();
        });
    });

    this.When(/^I PATCH (.*)$/, function (resource, callback) {
        this.apickli.patch(resource, function (error, response) {
            if (error) {
                callback(new Error(error));
            }

            callback();
        });
    });

    this.When(/^I request OPTIONS for (.*)$/, function(resource, callback) {
        this.apickli.options(resource, function(error, response) {
            if (error) {
                callback(new Error(error));
            }

            callback();
        });
    });

    this.Then(/^response header (.*) should exist$/, function (header, callback) {
        var assertion = this.apickli.assertResponseContainsHeader(header);

        if (assertion.success) {
            callback();
        } else {
            callback(prettyPrintJson(assertion));
        }
    });

    this.Then(/^response header (.*) should not exist$/, function (header, callback) {
        var assertion = this.apickli.assertResponseContainsHeader(header);
        assertion.success = !assertion.success;

        if (assertion.success) {
            callback();
        } else {
            callback(prettyPrintJson(assertion));
        }
    });

    this.Then(/^response body should be valid (xml|json)$/, function (contentType, callback) {
        var assertion = this.apickli.assertResponseBodyContentType(contentType);

        if (assertion.success) {
            callback();
        } else {
            callback(prettyPrintJson(assertion));
        }
    });

    this.Then(/^response code should be (.*)$/, function (responseCode, callback) {
        var assertion = this.apickli.assertResponseCode(responseCode);

        if (assertion.success) {
            callback();
        } else {
            callback(prettyPrintJson(assertion));
        }
    });

    this.Then(/^response code should not be (.*)$/, function (responseCode, callback) {
        var assertion = this.apickli.assertResponseCode(responseCode);
        assertion.success = !assertion.success;

        if (assertion.success) {
            callback();
        } else {
            callback(prettyPrintJson(assertion));
        }
    });

    this.Then(/^response header (.*) should be (.*)$/, function (header, expression, callback) {
        var assertion = this.apickli.assertHeaderValue(header, expression);

        if (assertion.success) {
            callback();
        } else {
            callback(prettyPrintJson(assertion));
        }
    });

    this.Then(/^response header (.*) should not be (.*)$/, function (header, expression, callback) {
        var assertion = this.apickli.assertHeaderValue(header, expression);
        assertion.success = !assertion.success;

        if (assertion.success) {
            callback();
        } else {
            callback(prettyPrintJson(assertion));
        }
    });

    this.Then(/^response body should contain (.*)$/, function (expression, callback) {
        var assertion = this.apickli.assertResponseBodyContainsExpression(expression);

        if (assertion.success) {
            callback();
        } else {
            callback(prettyPrintJson(assertion));
        }
    });

    this.Then(/^response body should not contain (.*)$/, function (expression, callback) {
        var assertion = this.apickli.assertResponseBodyContainsExpression(expression);
        assertion.success = !assertion.success;

        if (assertion.success) {
            callback();
        } else {
            callback(prettyPrintJson(assertion));
        }
    });

    this.Then(/^response body path (.*) should be ((?!of type).+)$/, function (path, value, callback) {
        var assertion = this.apickli.assertPathInResponseBodyMatchesExpression(path, value);

        if (assertion.success) {
            callback();
        } else {
            callback(prettyPrintJson(assertion));
        }
    });

    this.Then(/^response body path (.*) should not be ((?!of type).+)$/, function (path, value, callback) {
        var assertion = this.apickli.assertPathInResponseBodyMatchesExpression(path, value);
        assertion.success = !assertion.success;

        if (assertion.success) {
            callback();
        } else {
            callback(prettyPrintJson(assertion));
        }
    });

    this.Then(/^response body path (.*) should be of type array$/, function(path, callback) {
        var assertion = this.apickli.assertPathIsArray(path);
        if (assertion.success) {
            callback();
        } else {
            callback(prettyPrintJson(assertion));
        }
    });

    this.Then(/^response body path (.*) should be of type array with length (.*)$/, function(path, length, callback) {
        var assertion = this.apickli.assertPathIsArrayWithLength(path, length);
        if (assertion.success) {
            callback();
        } else {
            callback(prettyPrintJson(assertion));
        }
    });

    this.Then(/^response body should be valid according to schema file (.*)$/, function(schemaFile, callback) {
        this.apickli.validateResponseWithSchema(schemaFile, function (assertion) {
            if (assertion.success) {
                callback();
            } else {
                callback(prettyPrintJson(assertion));
            }
        });
    });

    this.Then(/^response body should be valid according to swagger definition (.*) in file (.*)$/, function(definitionName, swaggerSpecFile, callback) {
        this.apickli.validateResponseWithSwaggerSpecDefinition(definitionName, swaggerSpecFile, function (assertion) {
            if (assertion.success) {
                callback();
            } else {
                callback(prettyPrintJson(assertion));
            }
        });
    });

    this.Then(/^I store the value of body path (.*) as access token$/, function (path, callback) {
        this.apickli.setAccessTokenFromResponseBodyPath(path);
        callback();
    });

    this.When(/^I set bearer token$/, function (callback) {
        this.apickli.setBearerToken();
        callback();
    });

    this.Then(/^I store the value of response header (.*) as (.*) in global scope$/, function (headerName, variableName, callback) {
        this.apickli.storeValueOfHeaderInGlobalScope(headerName, variableName);
        callback();
    });

    this.Then(/^I store the value of body path (.*) as (.*) in global scope$/, function (path, variableName, callback) {
        this.apickli.storeValueOfResponseBodyPathInGlobalScope(path, variableName);
        callback();
    });

    this.Then(/^I store the value of response header (.*) as (.*) in scenario scope$/, function (name, variable, callback) {
        this.apickli.storeValueOfHeaderInScenarioScope(name, variable);
        callback();
    });

    this.Then(/^I store the value of body path (.*) as (.*) in scenario scope$/, function (path, variable, callback) {
        this.apickli.storeValueOfResponseBodyPathInScenarioScope(path, variable);
        callback();
    });

    this.Then(/^value of scenario variable (.*) should be (.*)$/, function (variableName, variableValue, callback) {
        if (this.apickli.assertScenarioVariableValue(variableName, variableValue)) {
            callback();
        } else {
            callback(new Error('value of variable ' + variableName + ' isn\'t equal to ' + variableValue));
        }
    });
};

var prettyPrintJson = function(json) {
    var output = {
        stepContext: stepContext,
        testOutput: json
    };

    return prettyJson.render(output, {
        noColor: true
    });
};