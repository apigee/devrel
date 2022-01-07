/**
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
var products = [];

var productResponse = context.getVariable("productResponse");
// parse JSON from Spanner response
var dataSet = JSON.parse(productResponse.content);

// create the JSON products response
for(var i=0; i < dataSet.rows.length; i++) {
	products.push({
	        "productid": dataSet.rows[i][0],
            "name": dataSet.rows[i][1],
            "description": dataSet.rows[i][2],
            "price": "" + dataSet.rows[i][3],
            "image": dataSet.rows[i][4]
	});		
}	

var output = { "products" : products };

// convert object to a string and replace the HTTP response with new, formatted data
context.proxyResponse.content = JSON.stringify(output);
