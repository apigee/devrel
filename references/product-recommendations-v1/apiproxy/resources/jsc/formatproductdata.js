var products = []; // array to hold temperature data

var productResponse = context.getVariable("productResponse");
// parse JSON from Spanner response
var dataSet = JSON.parse(productResponse.content);

// add date and temperture data to array
for(var i=0; i < dataSet.rows.length; i++) {
	products.push(
	    {
	        "productid": dataSet.rows[i][0],
            "name": dataSet.rows[i][1],
            "description": dataSet.rows[i][2],
            "price": "" + dataSet.rows[i][3],
            "image": dataSet.rows[i][4]
	    }
    );		
}	

var output = { "products" : products };

// convert object to a string and replace the HTTP response with new, formatted data
context.proxyResponse.content = JSON.stringify(output);

// For integration tests, to test when cache was set.
context.setVariable("response.header.x-cache-control", context.getVariable("request.header.cache-control"));
