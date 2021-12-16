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


