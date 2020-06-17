// PopulateDefaultErrorVariables.js

function setFault(status, phrase, code, message, url) {
  context.setVariable("custom.error.code", code);
  context.setVariable("custom.error.message", message);
  context.setVariable("custom.error.url", 
    url ? url : "https://developers.example.com");
  context.setVariable("custom.error.status", status);
  context.setVariable("custom.error.phrase", phrase);
}

switch (context.getVariable("fault.name")) {
  case "access_token_expired":  
  case "invalid_access_token": 
  case "InvalidAccessToken": 
    setFault(401, "Unauthorized", "401.99", "Unauthorized - Token Invalid or Expired");
    break;
  case "ErrorResponseCode":
    switch (context.getVariable("response.status.code")) {
      case "400":
        setFault(400, "Bad Request", "400.99", "Invalid Request");
        break;
      case "404":
        setFault(404, "Resource Not Found", "404.99", "Resource Not Found");
        break;
    }
}

if(!context.getVariable("custom.error.code")) {
  setFault(500, "Internal Server Error", "500.99", "Internal Server Error")
}
