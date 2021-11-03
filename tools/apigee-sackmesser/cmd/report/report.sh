#!/bin/bash
# shellcheck disable=SC2154
# SC2154: Variables are sent in ../../bin/sackmesser

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

if [ -z $organization ]; then
    logfatal "No Apigee Organization Specified. Use -o ORGANIZATION to set the Apigee Organization you want to analyze"
    exit 1
fi

if [ -z $environment ]; then
    logfatal "No Apigee Environment Specified. Use -e ENVIRONMENT to set the Apigee Environment you want to analyze"
    exit 1
fi

if [ -d "$export_folder" ]; then
    logerror "Folder $export_folder already exists. Please remove/rename and try again."
    exit 1
fi

export export_folder="$PWD/report-$organization-$environment"
export report_html="$export_folder/index.html"
mkdir -p "$export_folder/scratch/proxyrevisions"
cat "$SCRIPT_FOLDER/static/header.html" > "$report_html"
echo "<h1>Sackmesser Report</h1>" >> "$report_html"

echo "<div class=\"mdc-card mdc-card--outlined\">" >> "$report_html"
echo "<div class=\"mdc-card__content\">" >> "$report_html"
echo "<p><b>Organization:</b> $organization</p>" >> "$report_html"
echo "<p><b>Environment:</b> $environment</p>" >> "$report_html"
echo "<p><b>Timestamp:</b> $(date -n)</p>" >> "$report_html"
echo "</div>" >> "$report_html"
echo "</div>">> "$report_html" >> "$report_html"


loginfo "Exporting organization to $export_folder"
mkdir -p "$export_folder"
pushd "$export_folder"
sackmesser export -o "$organization" --skip-config
popd

loginfo "Running Apigeelint on Proxies"
mkdir -p "$export_folder/apigeelint/proxies"

for proxyexportpath in "$export_folder/$organization/proxies/"*/ ; do
    proxyname=$(basename $proxyexportpath)
    logdebug "Running Apigeelint on: $proxyexportpath"
    apigeelint -s "$proxyexportpath/apiproxy" -f html.js > "$export_folder/apigeelint/proxies/$proxyname.html" || true # apigeelint exits on error but we want to continue
    apigeelint -s "$proxyexportpath/apiproxy" -f json.js > "$export_folder/apigeelint/proxies/$proxyname.json" || true #
done

performancequery="organizations/$organization/environments/$environment/stats/apiproxy"
performancequery+="?limit=14400&offset=0"
performancequery+="&select=sum(message_count)/3600.0,sum(is_error),avg(target_response_time),avg(total_response_time)"
performancequery+="&timeUnit=day"
performancequery+="&timeRange=$(date -u -v1d '+%m/%d/%Y%%20%H:%M:%S')~$(date -u '+%m/%d/%Y%%20%H:%M:%S')"
sackmesser list "$performancequery" > "$export_folder/performance-$environment.json"

loginfo "Generating Policy Usage Report"

mkdir -p "$export_folder/scratch/policyusage"
for proxyexportpath in "$export_folder/$organization/proxies/"*/ ; do
    proxyname=$(basename $proxyexportpath)
    logdebug "Running Proxy Usage Analysis on: $proxyexportpath"
    if [ -d "$proxyexportpath"/apiproxy/policies ];then
        mkdir -p "$export_folder/scratch/policyusage/$proxyname"
        for proxypolicy in "$proxyexportpath"/apiproxy/policies/*.xml; do
            policytype=$(awk '/./{line=$0} END{print line}' "$proxypolicy" | sed 's@</\(.*\)>@\1@' )
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
done

sort "$export_folder/allpolicies.txt" | uniq > "$export_folder/uniquepolicies.txt"

echo "<h2>Proxies</h2>" >> "$report_html"

loginfo "Exporting Proxy Implementation"

echo "<h3>Proxy Implementation</h3>" >> "$report_html"

proxydeployments="$export_folder/proxy-deployments-$environment.json"
sfdeployments="$export_folder/sf-deployments-$environment.json"
loginfo "Listing Deployed Revisions"
sackmesser list "organizations/$organization/environments/$environment/deployments" > "$proxydeployments"
sackmesser list "organizations/$organization/environments/$environment/deployments?sharedFlows=true" > "$sfdeployments"

echo "<div class=\"mdc-data-table\"><div class=\"mdc-data-table__table-container\"><table class=\"mdc-data-table__table\">" >> "$report_html"
echo "<thead><tr class=\"mdc-data-table__header-row\">" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Proxy</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Rev. $environment</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Apigeelint Errors</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Apigeelint Warnings</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Apigeelint Report</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Numer of Policies</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Numer of Flows</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"
for proxylint in "$export_folder/apigeelint/proxies/"*.json ; do
    proxyname=$(basename "${proxylint%%.*}")
    proxyexportpath="$export_folder/$organization/proxies/$proxyname"
    errorCount=$(jq "[.[].errorCount] | add" $proxylint)
    warningCount=$(jq "[.[].warningCount] | add" $proxylint)

     if [ "$errorCount" -gt "0" ];then
        highlightclass="highlight-error"
    elif [ "$warningCount" -gt "0" ];then
        highlightclass="highlight-warn"
    else
        highlightclass=""
    fi

    deployedrevision=$(jq --arg PROXY_NAME "$proxyname" '.[]|select(.name==$PROXY_NAME).revision' $proxydeployments)
    latestrevision=$(xmllint --xpath 'string(/APIProxy/@revision)' "/$proxyexportpath/apiproxy/$proxyname.xml")

    if [ -n "$deployedrevision" ];then
        linkrevision="$deployedrevision"
        versionlag="$(($deployedrevision-$latestrevision))"
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
        policycount=$(ls "$proxyexportpath"/apiproxy/policies/*.xml | wc -l)
    else
        policycount=0
    fi

    if [ -f "$proxyexportpath/apiproxy/proxies/default.xml" ]; then
        flowcount=$(xmllint -xpath 'count(//Flows/Flow)' "$proxyexportpath/apiproxy/proxies/default.xml")
    else
        flowcount=0
    fi

    echo "<tr class=\"mdc-data-table__row $highlightclass\">"  >> "$report_html"
    echo "<th class=\"mdc-data-table__cell\" scope=\"row\"><a href="$(resource_link proxies/$proxyname $linkrevision)" target="_blank">$proxyname</a></th>" >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\" scope="row">$deployedrevision $versionlagicon</td>" >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\">$errorCount</td>" >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\">$warningCount</td>" >> "$report_html"
    echo "<td class=\"mdc-data-table__cell\"><a href=\"./apigeelint/proxies/$proxyname.html\" target="_blank">link</a></td>" >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\" scope="row">$policycount</td>" >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\" scope="row">$flowcount</td>" >> "$report_html"
    echo "</tr>"  >> "$report_html"
done
echo "</tbody></table></div></div>" >> "$report_html"

echo "<h3>Proxy Policies</h3>" >> "$report_html"

echo "<div class=\"mdc-data-table\"><div class=\"mdc-data-table__table-container\"><table class=\"mdc-data-table__table\">" >> "$report_html"
echo "<thead><tr class=\"mdc-data-table__header-row\">" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Proxy</th>" >> "$report_html"

while read policytype; do
  echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">$policytype</th>" >> "$report_html"
done <"$export_folder/uniquepolicies.txt"

echo "</tr></thead>" >> "$report_html"
echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

for policyusage in "$export_folder/scratch/policyusage/"*-indexed.json; do
    proxyname=$(basename "${policyusage%%-indexed.*}")
    linkrevision=$(cat "$export_folder/scratch/proxyrevisions/$proxyname")
    echo "<tr class=\"mdc-data-table__row\">"  >> "$report_html"
    echo "<th class=\"mdc-data-table__cell\" scope=\"row\"><a href="$(resource_link proxies/$proxyname $linkrevision)" target="_blank">$proxyname</a></th>" >> "$report_html"

    while read policytype; do
        usages=$(jq --arg TYPE "$policytype" '.[$TYPE] | length' "$policyusage")
        if [ "$usages" -gt "0" ];then
            usagedisplay=$usages
        else
           usagedisplay=''
        fi

        echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\">$usagedisplay</td>"  >> "$report_html"
    done <"$export_folder/uniquepolicies.txt"

    echo "</tr>"  >> "$report_html"
done

echo "</tbody></table></div></div>" >> "$report_html"

loginfo "Exporting Proxy Performance"

echo "<h3>Proxy Performance (last 24h)</h3>" >> "$report_html"

echo "<div class=\"mdc-data-table\"><div class=\"mdc-data-table__table-container\"><table class=\"mdc-data-table__table\">" >> "$report_html"
echo "<thead><tr class=\"mdc-data-table__header-row\">" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Proxy</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Avg. TPS</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Avg. Total Response Time</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Avg. Target Response Time</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Avg. Proxy Response Time</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Errors</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"

cat "$export_folder/performance-$environment.json" | jq -r -c '.environments[0].dimensions[]?' | while read -r dimension; do
    proxyname=$(echo "$dimension" | jq -r ".name")
    linkrevision=$(cat "$export_folder/scratch/proxyrevisions/$proxyname" || echo "unknown")
    avg_total_response_time=$(echo "$dimension" | jq -r '.metrics[]|select(.name=="avg(total_response_time)").values[0].value|tonumber|floor')
    avg_target_response_time=$(echo "$dimension" | jq -r '.metrics[]|select(.name=="avg(target_response_time)").values[0].value|tonumber|floor')
    avg_proxy_response_time="$(($avg_total_response_time - $avg_target_response_time))"
    avg_tps=$(echo "$dimension" | jq -r '.metrics[]|select(.name=="sum(message_count)/3600.0").values[0].value')
    errors=$(echo "$dimension" | jq -r '.metrics[]|select(.name=="sum(is_error)").values[0].value')

    echo "<tr class=\"mdc-data-table__row\">"  >> "$report_html"
    echo "<th class=\"mdc-data-table__cell\" scope=\"row\"><a href="$(resource_link proxies/$proxyname $linkrevision)" target="_blank">$proxyname</a></th>" >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\">$avg_tps</td>"  >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\">$avg_total_response_time</td>"  >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\">$avg_target_response_time</td>"  >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\">$avg_proxy_response_time</td>"  >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\">$errors</td>"  >> "$report_html"
    echo "</tr>"  >> "$report_html"
done
echo "</tbody></table></div></div>" >> "$report_html"

echo "<h2>SharedFlows</h2>" >> "$report_html"

echo "<h3>SharedFlows Implementation</h3>" >> "$report_html"

mkdir -p "$export_folder/apigeelint/sharedflows"
for sfexportpath in "$export_folder/$organization/sharedflows/"*/ ; do
    sfname=$(basename $sfexportpath)
    logdebug "Running Apigeelint on: $sfexportpath"
    apigeelint -s "$sfexportpath/sharedflowbundle" -f html.js > "$export_folder/apigeelint/sharedflows/$sfname.html" || true # apigeelint exits on error but we want to continue
    apigeelint -s "$sfexportpath/sharedflowbundle" -f json.js > "$export_folder/apigeelint/sharedflows/$sfname.json" || true #
done

echo "<div class=\"mdc-data-table\"><div class=\"mdc-data-table__table-container\"><table class=\"mdc-data-table__table\">" >> "$report_html"
echo "<thead><tr class=\"mdc-data-table__header-row\">" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">SharedFlow</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Rev. $environment</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Apigeelint Errors</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Apigeelint Warnings</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Apigeelint Report</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Numer of Policies</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Proxy References</th>" >> "$report_html"
echo "<th class=\"mdc-data-table__header-cell\" role=\"columnheader\" scope=\"col\">Flowhook References</th>" >> "$report_html"
echo "</tr></thead>" >> "$report_html"

echo "<tbody class=\"mdc-data-table__content\">" >> "$report_html"
for sflint in "$export_folder/apigeelint/sharedflows/"*.json ; do
    sfname=$(basename "${sflint%%.*}")
    sfexportpath="$export_folder/$organization/sharedflows/$sfname"
    errorCount=$(jq "[.[].errorCount] | add" $sflint)
    warningCount=$(jq "[.[].warningCount] | add" $sflint)

    if [ "$errorCount" -gt "0" ];then
        highlightclass="highlight-error"
    elif [ "$warningCount" -gt "0" ];then
        highlightclass="highlight-warn"
    else
        highlightclass=""
    fi

    deployedrevision=$(jq --arg SF_NAME "$sfname" '.[]|select(.name==$SF_NAME).revision' $sfdeployments)
    latestrevision=$(xmllint --xpath 'string(/SharedFlowBundle/@revision)' "/$sfexportpath/sharedflowbundle/$sfname.xml")

    if [ -n "$deployedrevision" ];then
        linkrevision="$deployedrevision"
        versionlag="$(($deployedrevision-$latestrevision))"
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
        policycount=$(ls "$sfexportpath"/sharedflowbundle/policies/*.xml | wc -l)
    else
        policycount=0
    fi

    proxyreferences=$(grep -r "$export_folder/$organization/proxies" -e "$sfname" | wc -l)

    flowhookexport="$export_folder/$organization/config/resources/edge/env/$environment/flowhooks.json"
    if [ -f "$flowhookexport" ] && [ -n "$(grep "$flowhookexport" -e "$sfname")" ];then
        usedinflowhook=yes
    else
        usedinflowhook=no
    fi

    echo "<tr class=\"mdc-data-table__row $highlightclass\">"  >> "$report_html"
    echo "<th class=\"mdc-data-table__cell\" scope="row"><a href="$(resource_link sharedflows/$sfname $linkrevision)" target="_blank">$sfname<a></th>" >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\" scope="row">$deployedrevision $versionlagicon</td>" >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\">$errorCount</td>"  >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\">$warningCount</td>"  >> "$report_html"
    echo "<td class=\"mdc-data-table__cell\"><a href=\"./apigeelint/sharedflows/$sfname.html\"  target="_blank">link</a></td>"  >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\" scope="row">$policycount</td>" >> "$report_html"
    echo "<td class=\"mdc-data-table__cell mdc-data-table__cell--numeric\" scope="row">$proxyreferences</td>" >> "$report_html"
    echo "<td class=\"mdc-data-table__cell\" scope="row">$usedinflowhook</th>" >> "$report_html"
    echo "</tr>"  >> "$report_html"
done
echo "</tbody></table></div></div>" >> "$report_html"
