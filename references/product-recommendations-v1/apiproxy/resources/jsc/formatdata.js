var recommendations = []; // array to hold temperature data

// parse JSON from BigQuery response
var dataSet = JSON.parse(context.proxyResponse.content);

// add product id to recommentations
for(var i=0; i < dataSet.totalRows; i++) {
	recommendations.push({"productid": dataSet.rows[i].f[0].v
	});		
}	

var output = { "products" : recommendations };

// convert object to a string and replace the HTTP response with new, formatted data
context.proxyResponse.content = JSON.stringify(output);


