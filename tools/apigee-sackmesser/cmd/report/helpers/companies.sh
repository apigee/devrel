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

echo "<h3>Companies</h3>" >> "$report_html"

mkdir -p "$export_folder/$organization/config/resources/edge/env/$environment/company"

sackmesser list "organizations/$organization/companies"| jq -r -c '.[]|.' | while read -r companyname; do
        sackmesser list "organizations/$organization/companies/$(urlencode "$companyname")" > "$export_folder/$organization/config/resources/edge/env/$environment/company/$(urlencode "$companyname")".json
    done

if ls "$export_folder/$organization/config/resources/edge/env/$environment/company"/*.json 1> /dev/null 2>&1; then
    jq -n '[inputs]' "$export_folder/$organization/config/resources/edge/env/$environment/company"/*.json > "$export_folder/$organization/config/resources/edge/env/$environment/companies".json
fi

echo "<div><table id=\"company-lint\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"id\">Name</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"name\">Display Name</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"status\">Status</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"apps\">Apps</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

if [ -f "$export_folder/$organization/config/resources/edge/env/$environment/companies".json ]; then
    jq -c '.[]' "$export_folder/$organization/config/resources/edge/env/$environment/companies".json | while read i; do 
        name=$(echo "$i" | jq -r '.name')
        displayName=$(echo "$i" | jq -r '.displayName')
        _status=$(echo "$i" | jq -r '.status')
        apps=$(echo "$i" | jq -r '.apps[]?')

        if [ $_status = "active" ]
            then
                status="✅"
            else
                status="❌"
        fi

        echo "<tr class=\"$highlightclass\">"  >> "$report_html"
        echo "<td>$name</td>"  >> "$report_html"
        echo "<td>"$displayName"</td>"  >> "$report_html"
        echo "<td>$status</td>" >> "$report_html"
        echo "<td>$apps</td>" >> "$report_html"
        echo "</tr>"  >> "$report_html"
    done
fi

echo "</tbody></table></div>" >> "$report_html"
