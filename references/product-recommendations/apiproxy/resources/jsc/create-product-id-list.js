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
/*
Creates SQL query
    SELECT productid,name,description,price,image, 
    // start selectCaseStr
    CASE productid 
    	WHEN 'GGOEGAAX0568' then 0 
    	WHEN 'GGOEGFKQ020399' then 1 
    	WHEN 'GGOEGAAX0690' then 2 
    	WHEN 'GGOEGDHB072199' then 3 
    	WHEN 'GGOEGHPB003410' then 4 
    	ELSE -1 end 
    AS sortid 
    // end selectCaseStr
    FROM products 
    WHERE productid in ('GGOEGAAX0568','GGOEGFKQ020399','GGOEGAAX0690','GGOEGDHB072199','GGOEGHPB003410') 
    ORDER BY sortid asc
*/
/* Convert JSON array to single quoted string of values for SQL query later
    productIdArray: ["GGOEGAAX0037","GGOEYDHJ056099","GGOEGAAX0351","GGOEGDWC020199","GGOEGAAX0318"]
    productIdList: "GGOEGAAX0037,GGOEYDHJ056099,GGOEGAAX0351,GGOEGDWC020199,GGOEGAAX0318"
    result: "'GGOEGAAX0037','GGOEYDHJ056099','GGOEGAAX0351','GGOEGDWC020199','GGOEGAAX0318'"
*/
var productIdArray = JSON.parse(context.getVariable("productIdList"));
var productIdList = productIdArray.join(",");
var result = '\'' + productIdList.split(',').join('\',\'') + '\'';
context.setVariable("productIdList",result);

var selectCaseStr = ", case productid ";
for (var i=0;i<productIdArray.length;i++)
{
 selectCaseStr += " when '" + productIdArray[i] + "' then " + i;
}
selectCaseStr += " else -1 end as sortid";
context.setVariable("selectCaseStr",selectCaseStr);