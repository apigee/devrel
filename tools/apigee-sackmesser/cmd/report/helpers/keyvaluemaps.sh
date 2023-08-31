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

echo "<h3>Key Value Maps</h3>" >> "$report_html"
echo "<p><strong>Note</strong>If migrating from Apigee Private Cloud (OPDK) to Apigee X/hybrid, Unencrypted KVMs will have to be converted to Encrypted KVMs.</p>" >> "$report_html"

mkdir -p "$export_folder/$organization/config/resources/edge/env/$environment/kvm"

sackmesser list "organizations/$organization/environments/$environment/keyvaluemaps"| jq -r -c '.[]|.' | while read -r kvmname; do
        sackmesser list "organizations/$organization/environments/$environment/keyvaluemaps/$(urlencode "$kvmname")" > "$export_folder/$organization/config/resources/edge/env/$environment/kvm/$(urlencode "$kvmname")".json
    done

if ls "$export_folder/$organization/config/resources/edge/env/$environment/kvm"/*.json 1> /dev/null 2>&1; then
    jq -n '[inputs]' "$export_folder/$organization/config/resources/edge/env/$environment/kvm"/*.json > "$export_folder/$organization/config/resources/edge/env/$environment/kvms".json
fi

echo "<div><table id=\"kvm-lint\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"id\">Name</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"encrypted\">Encrypted</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"keys\">Number of Keys</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

if [ -f "$export_folder/$organization/config/resources/edge/env/$environment/kvms".json ]; then
    jq -c '.[]' "$export_folder/$organization/config/resources/edge/env/$environment/kvms".json | while read i; do 
        name=$(echo "$i" | jq -r '.name')
        _encrypted=$(echo "$i" | jq -r '.encrypted')
        keyCount=$(echo "$i" | jq -r '.entry | length')

        if [ $_encrypted = true ]
            then
                encrypted="✅"
            else
                encrypted="❌"
        fi

        echo "<tr class=\"$highlightclass\">"  >> "$report_html"
        echo "<td>$name</td>"  >> "$report_html"
        echo "<td>"$encrypted"</td>"  >> "$report_html"
        echo "<td>$keyCount</td>" >> "$report_html"
        echo "</tr>"  >> "$report_html"
    done
fi

echo "</tbody></table></div>" >> "$report_html"
