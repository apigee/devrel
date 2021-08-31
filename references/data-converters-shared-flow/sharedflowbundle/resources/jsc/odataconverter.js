function ConvertODataToRest(inputObject, resource) {

    var newBody = {};
    
    if (inputObject.d) {
        if (inputObject.d.results && !newBody[resource])
            newBody[resource] = [];
                
        if (inputObject.d.results) {
            for (i=0; i<inputObject.d.results.length; i++) {
                var record = inputObject.d.results[i];
                
                newBody[resource].push(convertObject(record));
            }
        }
        else {
            newBody = convertObject(inputObject.d);
        }
    }
    else
        print("No OData body found to convert.")
    
    return newBody;
}

function convertObject(inputObj) {
    var result = {};
    
    for (var prop in inputObj) {

        var myVar = inputObj[prop];

        if ((typeof myVar === 'string' || myVar instanceof String) && myVar !== "")
            result[prop] = inputObj[prop];        
    }
    
    return result;
}

if (typeof exports !== 'undefined') {
    exports.ConvertODataToRest = ConvertODataToRest;
}
