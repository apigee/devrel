#!/bin/bash

# shellcheck disable=SC2154
# SC2154: Variables are sent in ../../bin/sackmesser
# shellcheck disable=SC2129
# SC2129: Cleaner redirect to html output

# Copyright 2021 Google LLC
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

set -e

SCRIPT_FOLDER=$( (cd "$(dirname "$0")" && pwd ))
source "$SCRIPT_FOLDER/../../lib/logutils.sh"

# Format URL to Apigee UI
# Attributes:
# $1 resource type and name e.g. proxies/my-proxy, sharedflows/my-sf
# $2 revision
function resource_link() {
    if [ "$apiversion" = "google" ]; then
        echo "https://apigee.google.com/platform/$organization/$1/develop/$2"
    elif [ "$apiversion" = "apigee" ]; then
        echo "https://apigee.com/platform/$organization/$1/develop/$2"
    fi
}

skip_api_export="${SKIP_API_EXPORT:-false}"
skip_api_lint="${SKIP_API_LINT:-false}"

if [ -z "$organization" ]; then
    logfatal "No Apigee Organization Specified. Use -o ORGANIZATION to set the Apigee Organization you want to analyze"
    exit 1
fi

if [ -z "$environment" ]; then
    logfatal "No Apigee Environment Specified. Use -e ENVIRONMENT to set the Apigee Environment you want to analyze"
    exit 1
fi

if ! grep -q "$environment" <<< "$(sackmesser list "organizations/$organization/environments/$environment")"; then
    logfatal "No Apigee Environment named: $environment found in Org: $organization"
    exit 1
fi

if [ -d "$export_folder" ] && [ "$skip_api_export" == "false" ]; then
    logerror "Folder $export_folder already exists. Please remove/rename and try again."
    exit 1
fi

export export_folder="$PWD/report-$organization-$environment"
export report_html="$export_folder/index.html"
mkdir -p "$export_folder/scratch/proxyrevisions"
cat "$SCRIPT_FOLDER/static/header.html" > "$report_html"

echo "<div class=\"card\"><div class=\"card-body\">" >> "$report_html"
echo "<p><b>Organization:</b> $organization</p>" >> "$report_html"
echo "<p><b>Environment:</b> $environment</p>" >> "$report_html"
echo "<p><b>Timestamp:</b> $(date)</p>" >> "$report_html"
echo "</div></div>" >> "$report_html"

loginfo "Exporting organization to $export_folder"
mkdir -p "$export_folder"
pushd "$export_folder"
if [ "$skip_api_export" == "false" ]; then
    sackmesser export -o "$organization" --skip-config
else
    loginfo "Skipping Export as SKIP_API_EXPORT env var is set to true"
fi
popd

if [ ! -d "$export_folder/$organization/proxies" ]; then
    mkdir -p "$export_folder/$organization/proxies"
    echo "<p><i>No API proxies found in organization $organization</i></p>" >> "$report_html"
fi

loginfo "Running Apigeelint on Proxies"
mkdir -p "$export_folder/apigeelint/proxies"

if [ "$skip_api_lint" == "false" ]; then
    while IFS= read -r -d '' proxyexportpath
    do
        proxyname=$(basename "$proxyexportpath")
        logdebug "Running Apigeelint on: $proxyexportpath"
        apigeelint -s "$proxyexportpath/apiproxy" -f html.js > "$export_folder/apigeelint/proxies/$proxyname.html" || true # apigeelint exits on error but we want to continue
        apigeelint -s "$proxyexportpath/apiproxy" -f json.js > "$export_folder/apigeelint/proxies/$proxyname.json" || true #
    done <   <(find "$export_folder/$organization/proxies" -type d -mindepth 1 -maxdepth 1 -print0)
else
    loginfo "Skipping Apigeelint as SKIP_API_LINT env var is set to true"
fi

performancequery="organizations/$organization/environments/$environment/stats/apiproxy"
performancequery+="?limit=14400&offset=0"
performancequery+="&select=sum(message_count)/3600.0,sum(is_error),avg(target_response_time),avg(total_response_time)"
performancequery+="&timeUnit=day"
PERFORMANCE_Q_START=$(date -u -v1d '+%m/%d/%Y%%2000:00:00' 2&>/dev/null || date -u -d "1 day ago" '+%m/%d/%Y%%2000:00:00' || date -u -d "@$(( $(date +%s ) - 86400 ))" '+%m/%d/%Y%%2000:00:00' || echo '')
performancequery+="&timeRange=$PERFORMANCE_Q_START~$(date -u '+%m/%d/%Y%%2000:00:00')"
sackmesser list "$performancequery" > "$export_folder/performance-$environment.json"

loginfo "Generating Policy Usage Report"

mkdir -p "$export_folder/scratch/policyusage"
while IFS= read -r -d '' proxyexportpath
do
    proxyname=$(basename "$proxyexportpath")
    logdebug "Running Proxy Usage Analysis on: $proxyexportpath"
    if [ -d "$proxyexportpath"/apiproxy/policies ];then
        mkdir -p "$export_folder/scratch/policyusage/$proxyname"
        for proxypolicy in "$proxyexportpath"/apiproxy/policies/*.xml; do
            policytype=$(xmllint -xpath "/*" "$proxypolicy" | awk '/./{line=$0} END{print line}' | sed 's@</\(.*\)>@\1@' )
            echo "$policytype" >> "$export_folder/allpolicies.txt"
            policyname=$(xmllint -xpath "string(/$policytype/@name)" "$proxypolicy")
            echo "{ \"type\": \"$policytype\", \"name\": \"$policyname\"}" > "$export_folder/scratch/policyusage/$proxyname/$policyname.json"
        done
        jq -n "[inputs]" "$export_folder/scratch/policyusage/$proxyname/"*.json > "$export_folder/scratch/policyusage/$proxyname.json"
        jq 'group_by(.type) | map({ key: (.[0].type), value: [.[] | .name] }) | from_entries' "$export_folder/scratch/policyusage/$proxyname.json" > "$export_folder/scratch/policyusage/$proxyname-indexed.json"

        rm -r "$export_folder/scratch/policyusage/$proxyname"
    else
        echo "[]" > "$export_folder/scratch/policyusage/$proxyname.json"
        echo "{}" > "$export_folder/scratch/policyusage/$proxyname-indexed.json"
    fi
done <   <(find "$export_folder/$organization/proxies" -type d -mindepth 1 -maxdepth 1 -print0)

sort "$export_folder/allpolicies.txt" | uniq > "$export_folder/uniquepolicies.txt"

echo "<h2>Proxies</h2>" >> "$report_html"

loginfo "Exporting Proxy Implementation"

echo "<h3>Proxy Implementation</h3>" >> "$report_html"

proxydeployments="$export_folder/proxy-deployments-$environment.json"
sfdeployments="$export_folder/sf-deployments-$environment.json"
loginfo "Listing Deployed Revisions"
sackmesser list "organizations/$organization/environments/$environment/deployments" > "$proxydeployments"
sackmesser list "organizations/$organization/environments/$environment/deployments?sharedFlows=true" > "$sfdeployments"

echo "<div><table id=\"proxy-lint\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"proxy-name\">Proxy</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"env\">Rev. $environment</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"errors\">Apigeelint Errors</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"lint-warn\">Apigeelint Warnings</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"lint-error\">Apigeelint Report</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"policies\">Number of Policies</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"flows\">Number of Flows</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

while IFS= read -r -d '' proxylint
do
    proxyname=$(basename "$proxylint")
    proxyname=${proxyname//.json/}
    proxyexportpath="$export_folder/$organization/proxies/$proxyname"
    if jq -e . >/dev/null 2>&1 <<<"$(cat "$proxylint")"; then
        errorCount=$(jq '[.[].errorCount] | add' "$proxylint")
        warningCount=$(jq '[.[].warningCount] | add' "$proxylint")
    else
        logwarn "Failed to parse JSON $proxylint, Skipping errorCount & warningCount check !"
        errorCount=0
        warningCount=0
    fi

    if [ "$errorCount" -gt "0" ];then
        highlightclass="highlight-error"
    elif [ "$warningCount" -gt "0" ];then
        highlightclass="highlight-warn"
    else
        highlightclass=""
    fi

    deployedrevision=$(jq --arg PROXY_NAME "$proxyname" '.[]|select(.name==$PROXY_NAME).revision' "$proxydeployments")
    latestrevision=$(xmllint --xpath 'string(/APIProxy/@revision)' "/$proxyexportpath/apiproxy/${proxyname//%20/ }.xml")

    if [ -n "$deployedrevision" ];then
        linkrevision="$deployedrevision"
        versionlag="$((deployedrevision-latestrevision))"
        if [ "$versionlag" -eq "0" ];then
            versionlagicon="✅"
        else
            versionlagicon="($versionlag) ⚠️"
        fi
    else
        versionlagicon=""
        linkrevision="$latestrevision"
    fi

    echo "$linkrevision" > "$export_folder/scratch/proxyrevisions/$proxyname"

    if [ -d "$proxyexportpath/apiproxy/policies" ];then
        policycount=$(find "$proxyexportpath"/apiproxy/policies/*.xml | wc -l)
    else
        policycount=0
    fi

    if [ -f "$proxyexportpath/apiproxy/proxies/default.xml" ]; then
        flowcount=$(xmllint -xpath 'count(//Flows/Flow)' "$proxyexportpath/apiproxy/proxies/default.xml")
    else
        flowcount=0
    fi

    echo "<tr class=\"$highlightclass\">"  >> "$report_html"
    echo "<th><a href=\"$(resource_link "proxies/$proxyname" "$linkrevision")\" target=\"_blank\">$proxyname</a></th>" >> "$report_html"
    echo "<td>$deployedrevision $versionlagicon</td>" >> "$report_html"
    echo "<td>$errorCount</td>" >> "$report_html"
    echo "<td>$warningCount</td>" >> "$report_html"
    echo "<td><a href=\"./apigeelint/proxies/$proxyname.html\" target=\"_blank\">link</a></td>" >> "$report_html"
    echo "<td>$policycount</td>" >> "$report_html"
    echo "<td>$flowcount</td>" >> "$report_html"
    echo "</tr>"  >> "$report_html"
done <   <(find "$export_folder/apigeelint/proxies/"*.json -print0)

echo "</tbody></table></div>" >> "$report_html"

echo "<h3>Proxy Policies</h3>" >> "$report_html"

echo "<div><table id=\"proxy-policies\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"proxy-name\">Proxy</th>" >> "$report_html"

while read -r policytype; do
  echo "<th data-sortable=\"true\" data-field=\"$policytype\">$policytype</th>" >> "$report_html"
done <"$export_folder/uniquepolicies.txt"

echo "</tr></thead>" >> "$report_html"
echo "<tbody>" >> "$report_html"

while IFS= read -r -d '' policyusage
do
    proxyname=$(basename "${policyusage%%-indexed.*}")
    if [ -f "$export_folder/scratch/proxyrevisions/$proxyname" ]; then
        linkrevision=$(cat "$export_folder/scratch/proxyrevisions/$proxyname")
    else
        linkrevision="unknown"
    fi
    echo "<tr>"  >> "$report_html"
    echo "<th scope=\"row\"><a href=\"$(resource_link "proxies/$proxyname" "$linkrevision")\" target=\"_blank\">$proxyname</a></th>" >> "$report_html"

    while read -r policytype; do
        usages=$(jq --arg TYPE "$policytype" '.[$TYPE] | length' "$policyusage")
        if [ "$usages" -gt "0" ];then
            usagedisplay=$usages
        else
           usagedisplay=''
        fi

        echo "<td>$usagedisplay</td>"  >> "$report_html"
    done <"$export_folder/uniquepolicies.txt"

    echo "</tr>"  >> "$report_html"
done <   <(find "$export_folder/scratch/policyusage/"*-indexed.json -print0)

echo "</tbody></table></div>" >> "$report_html"

loginfo "Exporting Proxy Performance"

echo "<h3>Proxy Performance (Yesterday)</h3>" >> "$report_html"

echo "<div><table id=\"proxy-perf\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"id\">Proxy</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"tps\">Avg. TPS</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"rt\">Avg. Total Response Time</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"trt\">Avg. Target Response Time</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"prt\">Avg. Proxy Response Time</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"errors\">Errors</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

jq -r -c '.environments[0].dimensions[]?' < "$export_folder/performance-$environment.json" | while read -r dimension; do
    proxyname=$(echo "$dimension" | jq -r ".name")
    if [ -f "$export_folder/scratch/proxyrevisions/$proxyname" ]; then
        linkrevision=$(cat "$export_folder/scratch/proxyrevisions/$proxyname")
    else
        linkrevision="unknown"
    fi
    avg_total_response_time=$(echo "$dimension" | jq -r '.metrics[]|select(.name=="avg(total_response_time)").values[0].value|tonumber|floor')
    avg_target_response_time=$(echo "$dimension" | jq -r '.metrics[]|select(.name=="avg(target_response_time)").values[0].value|tonumber|floor')
    avg_proxy_response_time="$((avg_total_response_time - avg_target_response_time))"
    avg_tps=$(echo "$dimension" | jq -r '.metrics[]|select(.name=="sum(message_count)/3600.0").values[0].value')
    errors=$(echo "$dimension" | jq -r '.metrics[]|select(.name=="sum(is_error)").values[0].value')

    echo "<tr>"  >> "$report_html"
    echo "<th scope=\"row\"><a href=\"$(resource_link "proxies/$proxyname" "$linkrevision")\" target=\"_blank\">$proxyname</a></th>" >> "$report_html"
    echo "<td>$avg_tps</td>"  >> "$report_html"
    echo "<td>$avg_total_response_time</td>"  >> "$report_html"
    echo "<td>$avg_target_response_time</td>"  >> "$report_html"
    echo "<td>$avg_proxy_response_time</td>"  >> "$report_html"
    echo "<td>$errors</td>"  >> "$report_html"
    echo "</tr>"  >> "$report_html"
done

echo "</tbody></table></div>" >> "$report_html"

echo "<h2>SharedFlows</h2>" >> "$report_html"

loginfo "Exporting SF Implementation"

if [ ! -d "$export_folder/$organization/sharedflows" ]; then
    mkdir -p "$export_folder/$organization/sharedflows"
    echo "<p><i>No SharedFlows found in organization $organization</i></p>" >> "$report_html"
fi

echo "<h3>SharedFlows Implementation</h3>" >> "$report_html"

mkdir -p "$export_folder/apigeelint/sharedflows"

while IFS= read -r -d '' sfexportpath
do
    sfname=$(basename "$sfexportpath")
    logdebug "Running Apigeelint on: $sfexportpath"
    apigeelint -s "$sfexportpath/sharedflowbundle" -f html.js > "$export_folder/apigeelint/sharedflows/$sfname.html" || true # apigeelint exits on error but we want to continue
    apigeelint -s "$sfexportpath/sharedflowbundle" -f json.js > "$export_folder/apigeelint/sharedflows/$sfname.json" || true #
done <   <(find "$export_folder/$organization/sharedflows" -type d -mindepth 1 -maxdepth 1 -print0)

echo "<div><table id=\"sf-lint\" data-toggle=\"table\" class=\"table\">" >> "$report_html"
echo "<thead class=\"thead-dark\"><tr>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"id\">SharedFlow</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"rev\">Rev. $environment</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"errors\">Apigeelint Errors</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"warn\">Apigeelint Warnings</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"lint\">Apigeelint Report</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"policies\">Number of Policies</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"references\">Proxy References</th>" >> "$report_html"
echo "<th data-sortable=\"true\" data-field=\"fh\">Flowhook References</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"
while IFS= read -r -d '' sflint
do
    sfname=$(basename "${sflint}")
    sfname=${sfname//.json/}
    sfexportpath="$export_folder/$organization/sharedflows/$sfname"

    if jq -e . >/dev/null 2>&1 <<<"$(cat "$sflint")"; then
        errorCount=$(jq '[.[].errorCount] | add' "$sflint")
        warningCount=$(jq '[.[].warningCount] | add' "$sflint")
    else
        logwarn "Failed to parse JSON $sflint, Skipping errorCount & warningCount check !"
        errorCount=0
        warningCount=0
    fi

    if [ "$errorCount" -gt "0" ];then
        highlightclass="highlight-error"
    elif [ "$warningCount" -gt "0" ];then
        highlightclass="highlight-warn"
    else
        highlightclass=""
    fi

    deployedrevision=$(jq --arg SF_NAME "$sfname" '.[]|select(.name==$SF_NAME).revision' "$sfdeployments")
    latestrevision=$(xmllint --xpath 'string(/SharedFlowBundle/@revision)' "/$sfexportpath/sharedflowbundle/${sfname//%20/ }.xml")

    if [ -n "$deployedrevision" ];then
        linkrevision="$deployedrevision"
        versionlag="$((deployedrevision-latestrevision))"
        if [ "$versionlag" -eq "0" ];then
            versionlagicon="✅"
        else
            versionlagicon="($versionlag) ⚠️"
        fi
    else
        versionlagicon=""
        linkrevision="$latestrevision"
    fi

    if [ -d "$sfexportpath/sharedflowbundle/policies" ];then
        policycount=$(find "$sfexportpath"/sharedflowbundle/policies/*.xml | wc -l)
    else
        policycount=0
    fi

    proxyreferences=$(grep -r "$export_folder/$organization/proxies" -e "$sfname" | wc -l)

    flowhookexport="$export_folder/$organization/config/resources/edge/env/$environment/flowhooks.json"
    if [ -f "$flowhookexport" ] && ! grep -q "$sfname" <<< "$flowhookexport";then
        usedinflowhook=yes
    else
        usedinflowhook=no
    fi

    echo "<tr class=\"$highlightclass\">"  >> "$report_html"
    echo "<th scope=\"row\"><a href=\"$(resource_link "sharedflows/$sfname" "$linkrevision")\" target=\"_blank\">$sfname<a></th>" >> "$report_html"
    echo "<td>$deployedrevision $versionlagicon</td>" >> "$report_html"
    echo "<td>$errorCount</td>"  >> "$report_html"
    echo "<td>$warningCount</td>"  >> "$report_html"
    echo "<td><a href=\"./apigeelint/sharedflows/$sfname.html\"  target=\"_blank\">link</a></td>"  >> "$report_html"
    echo "<td>$policycount</td>" >> "$report_html"
    echo "<td>$proxyreferences</td>" >> "$report_html"
    echo "<td>$usedinflowhook</td>" >> "$report_html"
    echo "</tr>"  >> "$report_html"
done <   <(find "$export_folder/apigeelint/sharedflows/"*.json -print0)

echo "</tbody></table></div>" >> "$report_html"

highlightclass=""

echo "<h2>Environment Configurations</h2>" >> "$report_html"

loginfo "Exporting Apigee Environment level configurations."

helper_dir=$SCRIPT_FOLDER/helpers

urlencode() {
    echo "\"${*:1}\"" | jq -r '@uri'
}

source $helper_dir/keyvaluemaps.sh
source $helper_dir/targetservers.sh
source $helper_dir/keystores.sh
source $helper_dir/caches.sh
source $helper_dir/flowhooks.sh
source $helper_dir/references.sh

if [ "$opdk" == "T" ]; then
    source $helper_dir/virtualhosts.sh
fi

echo "<h2>Organization Configurations</h2>" >> "$report_html"
loginfo "Exporting Apigee Organization level configurations."
source $helper_dir/apiproducts.sh
source $helper_dir/developers.sh
source $helper_dir/developerapps.sh

echo "</div>" >> "$report_html"
cat "$SCRIPT_FOLDER/static/footer.html" >> "$report_html"
loginfo "Sackmesser report is ready in: $report_html"
