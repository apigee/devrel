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

echo "<h3>Caches</h3>" >> "$report_html"

if [ "$apiversion" = "google" ]; then
    echo "<div><table id=\"cache-lint\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
    echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
    echo "<th data-sortable=\"true\" data-field=\"id\">Name</th>" >> "$report_html"
    echo "</tr></thead>" >> "$report_html"
    echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"
    
    sackmesser list "organizations/$organization/environments/$environment/caches"| jq -r -c '.[]|.' | while read -r cachename; do
        echo "<tr class=\"$highlightclass\">"  >> "$report_html"
        echo "<td>$cachename</td>"  >> "$report_html"
        echo "</tr>"  >> "$report_html"
    done

else

    mkdir -p "$export_folder/$organization/config/resources/edge/env/$environment/cache"

    sackmesser list "organizations/$organization/environments/$environment/caches"| jq -r -c '.[]|.' | while read -r cachename; do
        sackmesser list "organizations/$organization/environments/$environment/caches/$(urlencode "$cachename")" > "$export_folder/$organization/config/resources/edge/env/$environment/cache/$(urlencode "$cachename")".json
    done

    if ls "$export_folder/$organization/config/resources/edge/env/$environment/cache"/*.json 1> /dev/null 2>&1; then
        jq -n '[inputs]' "$export_folder/$organization/config/resources/edge/env/$environment/cache"/*.json > "$export_folder/$organization/config/resources/edge/env/$environment/caches".json
    fi

    echo "<div><table id=\"cache-lint\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
    echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
    echo "<th data-sortable=\"true\" data-field=\"id\">Name</th>" >> "$report_html"
    echo "<th data-sortable=\"true\" data-field=\"distributed\">Distributed</th>" >> "$report_html"
    echo "<th data-sortable=\"true\" data-field=\"persistent\">Persistent</th>" >> "$report_html"
    echo "<th data-sortable=\"true\" data-field=\"timeout\">Timeout</th>" >> "$report_html"
    echo "</tr></thead>" >> "$report_html"

    echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

    if [ -f "$export_folder/$organization/config/resources/edge/env/$environment/caches".json ]; then
        jq -c '.[]' "$export_folder/$organization/config/resources/edge/env/$environment/caches".json | while read i; do 
            name=$(echo "$i" | jq -r '.name')
            _isDistributed=$(echo "$i" | jq -r '.distributed')
            _isPersistent=$(echo "$i" | jq -r '.persistent')
            timeout=$(echo "$i" | jq -r '.expirySettings.timeoutInSec.value')

            if [ $_isDistributed = true ]
                then
                    isDistributed="✅"
                else
                    isDistributed="❌"
            fi

            if [ $_isPersistent = true ]
                then
                    isPersistent="✅"
                else
                    isPersistent="❌"
            fi

            echo "<tr class=\"$highlightclass\">"  >> "$report_html"
            echo "<td>$name</td>"  >> "$report_html"
            echo "<td>$isDistributed</td>" >> "$report_html"
            echo "<td>$isPersistent</td>" >> "$report_html"
            echo "<td>$timeout</td>" >> "$report_html"
            echo "</tr>"  >> "$report_html"
        done
    fi
fi

echo "</tbody></table></div>" >> "$report_html"