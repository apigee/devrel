#!/bin/bash

# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# <http://www.apache.org/licenses/LICENSE-2.0>
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

echo "<h3>Flow Hooks</h3>" >> "$report_html"

mkdir -p "$export_folder/$organization/config/resources/edge/env/$environment/flowhook"

sackmesser list "organizations/$organization/environments/$environment/flowhooks"| jq -r -c '.[]|.' | while read -r flowhookname; do
        sackmesser list "organizations/$organization/environments/$environment/flowhooks/$(urlencode "$flowhookname")" > "$export_folder/$organization/config/resources/edge/env/$environment/flowhook/$(urlencode "$flowhookname")".json
    done

if ls "$export_folder/$organization/config/resources/edge/env/$environment/flowhook"/*.json 1> /dev/null 2>&1; then
    jq -n '[inputs]' "$export_folder/$organization/config/resources/edge/env/$environment/flowhook"/*.json > "$export_folder/$organization/config/resources/edge/env/$environment/flowhooks".json
fi

echo "<div><table id=\"flowhook-lint\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"id\">Name</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"sharedflow\">Shared Flow</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"contonerr\">Continue On Error</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

if [ -f "$export_folder/$organization/config/resources/edge/env/$environment/flowhooks".json ]; then
    jq -c '.[]' "$export_folder/$organization/config/resources/edge/env/$environment/flowhooks".json | while read i; do 
        if [ "$opdk" == "T" ]; then
            name=$(echo "$i" | jq -r '.name')
        elif [ "$apiversion" = "google" ]; then
            name=$(echo "$i" | jq -r '.flowHookPoint')
        fi
        
        sharedFlow=$(echo "$i" | jq -r '.sharedFlow')
        _continueOnError=$(echo "$i" | jq -r '.continueOnError')

        if [ $_continueOnError = true ]
            then
                continueOnError="✅"
            else
                continueOnError="❌"
        fi
        if [ $name != null ]
            then
                echo "<tr class=\"$highlightclass\">"  >> "$report_html"
                echo "<td>$name</td>"  >> "$report_html"
                echo "<td>$sharedFlow</td>" >> "$report_html"
                echo "<td>$continueOnError</td>" >> "$report_html"
                echo "</tr>"  >> "$report_html"
        fi            
    done
fi

echo "</tbody></table></div>" >> "$report_html"
