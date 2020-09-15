#!/bin/sh

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
PIPELINE_REPORT="run-steps,0"                                         

for CMD in $(cat $SCRIPTPATH/steps.json | jq '.steps[]' -r); do
  $CMD
  PIPELINE_REPORT="$PIPELINE_REPORT;$CMD,$?"                     
done

echo                                                                                                                                    
echo "STEP RESULTS"                                                                                                                     
echo "$PIPELINE_REPORT" | tr ";" "\n" | awk -F"," '$2 = ($2 > 0 ? "fail" : "pass")' OFS=";" | column -s ";" -t                          
echo                                                                                                                                    
                                                                                                                                        
# set exit code                                                                                                                         
! echo "$PIPELINE_REPORT" | tr ";" "\n" | awk -F"," '{ print $2 }' | grep -v -q "0"
