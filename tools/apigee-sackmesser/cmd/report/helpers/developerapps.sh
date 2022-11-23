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

echo "<h3>Developer Apps</h3>" >> "$report_html"

mkdir -p "$export_folder/$organization/config/resources/edge/env/$environment/developerapps"

sackmesser list "organizations/$organization/developers" | jq -r -c '.[]|.' | while read -r email; do
    loginfo "download developer: $email"
    mkdir "$export_folder/$organization/config/resources/edge/env/$environment/developerapps/$email"
    sackmesser list "organizations/$organization/developers/$email/apps" | jq -r -c '.[]|.' | while read -r appId; do
        loginfo "download developer app: $appId for developer: $email"
        full_app=$(sackmesser list "organizations/$organization/developers/$email/apps/$(urlencode "$appId")")
        echo "$full_app" | jq 'del(.credentials)' > "$export_folder/$organization/config/resources/edge/env/$environment/developerapps/$appId".json
        echo "$full_app" | jq -r -c '.credentials[]' | while read -r credential; do
            appkey=$(echo "$credential" | jq -r '.consumerKey')
        done
    done
done

if ls "$export_folder/$organization/config/resources/edge/env/$environment/developerapps"/*.json 1> /dev/null 2>&1; then
    jq -n '[inputs]' "$export_folder/$organization/config/resources/edge/env/$environment/developerapps"/*.json > "$export_folder/$organization/config/resources/edge/env/$environment/developerapps".json
fi

echo "<div><table id=\"ts-lint\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"name\">Name</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"status\">Status</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"dev_id\">Developer ID</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"app_id\">App ID</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"app_fam\">App Family</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"callback\">Callback URL</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"access\">Access Type</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"created\">Created At</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"modified\">Last Modified</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"credentialsLoaded\">Credentials Loaded</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"scopes\">Scopes</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

if [ -f "$export_folder/$organization/config/resources/edge/env/$environment/developerapps".json ]; then
    jq -c '.[]' "$export_folder/$organization/config/resources/edge/env/$environment/developerapps".json | while read i; do 
        name=$(echo "$i" | jq -r '.name')
        status=$(echo "$i" | jq -r '.status')
        developerId=$(echo "$i" | jq -r '.developerId')
        appId=$(echo "$i" | jq -r '.appId')
        appFamily=$(echo "$i" | jq -r '.appFamily')
        callbackUrl=$(echo "$i" | jq -r '.callbackUrl')
        accessType=$(echo "$i" | jq -r '.accessType')
        createdAt=$(echo "$i" | jq -r '.createdAt' | date -u)
        lastModifiedAt=$(echo "$i" | jq -r '.lastModifiedAt' | date -u)
        _credentialsLoaded=$(echo "$i" | jq -r '.credentialsLoaded')
        scopes=$(echo "$i" | jq -r '.scopes')
        

        if [ $_credentialsLoaded = true ]
            then
                credentialsLoaded="✅"
            else
                credentialsLoaded="❌"
        fi

        echo "<tr class=\"$highlightclass\">"  >> "$report_html"
        echo "<td>$name</td>"  >> "$report_html"
        echo "<td>$status</td>"  >> "$report_html"
        echo "<td>$developerId</td>"  >> "$report_html"
        echo "<td>$appId</td>" >> "$report_html"
        echo "<td>$appFamily</td>" >> "$report_html"
        echo "<td>$callbackUrl</td>" >> "$report_html"
        echo "<td>$accessType</td>" >> "$report_html"
        echo "<td>$createdAt</td>" >> "$report_html"
        echo "<td>$lastModifiedAt</td>" >> "$report_html"
        echo "<td>$credentialsLoaded</td>" >> "$report_html"
        echo "<td>$scopes</td>" >> "$report_html"
        echo "</tr>"  >> "$report_html"
    done
fi

echo "</tbody></table></div>" >> "$report_html"