function ConvertBigQueryResponse(inputObject, resource) {
    var result = {};
    result[resource] = [];
    
    for (var rowKey in inputObject.rows) {
        var row = inputObject.rows[rowKey];
        var newRow = {};
        for (var valueKey in row.f) {
            var value = row.f[valueKey];
            newRow[inputObject.schema.fields[valueKey].name] = value.v;
        }
        result[resource].push(newRow);
    }
    
    return result;
}

if (typeof exports !== 'undefined') {
    exports.ConvertBigQueryResponse = ConvertBigQueryResponse;
}
