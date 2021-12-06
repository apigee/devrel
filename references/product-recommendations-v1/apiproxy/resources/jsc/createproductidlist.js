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