var input = context.getVariable("dataconverter.input");
var resource = context.getVariable("dataconverter.resource");

var newBody = ConvertBigQueryResponse(JSON.parse(input), resource);

context.setVariable("dataconverter.output", JSON.stringify(newBody));
