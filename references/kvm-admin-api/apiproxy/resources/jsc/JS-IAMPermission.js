var reqMethod = context.getVariable("request.verb");
var iamPermission = "apigee.keyvaluemaps.";

if(reqMethod === "POST")
    iamPermission += "create";
else if(reqMethod === "GET")
    iamPermission += "list";
else if(reqMethod === "DELETE")
    iamPermission += "delete";
else
    iamPermission += "noop";

var reqPayload = {permissions: [iamPermission]};
context.setVariable("iam.permission", iamPermission);
context.setVariable("iam.permissionPayload", JSON.stringify(reqPayload, null, 2));
