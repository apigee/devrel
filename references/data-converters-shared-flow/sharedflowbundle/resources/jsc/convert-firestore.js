var input = context.getVariable("dataconverter.input");
var resource = context.getVariable("dataconverter.resource");

var newBody = convertFsResponse(JSON.parse(input), resource, resource.substring(0, resource.length - 2) + "Id");

context.setVariable("dataconverter.output", JSON.stringify(newBody));
