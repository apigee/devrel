// PopulateDefaultErrorVariables.js

function setFault(status, phrase, code, message, url) {
  context.setVariable("custom.error.code", code);
  context.setVariable("custom.error.message", message);
  context.setVariable("custom.error.url", 
    url ? url : "https://developers.example.com");
  context.setVariable("custom.error.status", status);
  context.setVariable("custom.error.phrase", phrase);
}

// custom error handling here

