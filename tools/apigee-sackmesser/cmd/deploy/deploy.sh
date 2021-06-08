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

if ! which xmllint > /dev/null; then
    logfatal "please install xmllint command"
    exit 1
fi

# Make temp 'deploy' directory to keep things clean
temp_folder="$PWD/deploy-$(date +%s)-$RANDOM"
rm -rf "$temp_folder" && mkdir -p "$temp_folder"
cleanup() {
  loginfo "removing $temp_folder"
  rm  -rf "$temp_folder"
}
trap cleanup EXIT


# copy resources to temp directory
if [ -n "$url" ]; then
    pattern='https?:\/\/github.com\/([^\/]*)\/([^\/]*)\/tree\/([^\/]*)\/(.*)'
    [[ "$url" =~ $pattern ]]
    git_org="${BASH_REMATCH[1]}"
    git_repo="${BASH_REMATCH[2]}"
    git_branch="${BASH_REMATCH[3]}"
    git_path="${BASH_REMATCH[4]}"

    git clone "https://github.com/${git_org}/${git_repo}.git" "$temp_folder/$git_repo"
    (cd "$temp_folder/$git_repo" && git checkout "$git_branch")
    cp -R "$temp_folder/$git_repo/$git_path/"* "$temp_folder"
else
    source_dir="${directory:-$PWD}"
    loginfo "using local directory: $source_dir"
    [ -d "$source_dir/apiproxy" ] && cp -r "$source_dir/apiproxy" "$temp_folder/apiproxy"
    [ -d "$source_dir/sharedflowbundle" ] && cp -r "$source_dir/sharedflowbundle" "$temp_folder/sharedflowbundle"
    [ -e "$source_dir/edge.json" ] && cp "$source_dir/edge.json" "$temp_folder/"
fi

# Config Deployment
if [ -f "$temp_folder"/edge.json ]; then
    loginfo "Preparing config $temp_folder/edge.json"

    config_action='update'

    if [ "$apiversion" = "google" ]; then

        jq --arg APIGEE_ENV "$environment" -c '.envConfig[$APIGEE_ENV].kvms[]? | .' < "$temp_folder"/edge.json | while read -r line; do
            kvm=$(echo "$line" | jq -c 'del(.entry)')
            kvmname=$(echo "$kvm" | jq -r '.name')
            loginfo "X/hybrid patch: adding kvm: $kvmname"
            curl -X POST --fail "https://apigee.googleapis.com/v1/organizations/$organization/environments/$environment/keyvaluemaps" \
                -H "Authorization: Bearer $token" \
                -H "Content-Type: application/json" \
                --data "$kvm" || logwarn "failed to create KVM. Assuming it already exists"

            KVM_ADMIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" "https://apigee.googleapis.com/v1/organizations/$organization/environments/$environment/apis/kvm-admin-v1/deployments")

            loginfo "kvm admin status $KVM_ADMIN_STATUS"

            if [ "$KVM_ADMIN_STATUS" != "200" ];then
                loginfo "creating kvm admin proxy"
                "$SCRIPT_FOLDER/../../bin/sackmesser" deploy --googleapi -d "$SCRIPT_FOLDER/../../../../references/kvm-admin-api" -t "$token" \
                    -o "$organization" -e "$environment"
            fi

            echo "$line" | jq -c  '.entry[]? | .' | while read -r kvmentry; do
                kvmentry=$(echo "$kvmentry" | jq '.["key"]=.name | del(.name)')
                loginfo "adding entry: $(echo "$kvmentry" | jq '.key')"
                curl -s -X POST -k --fail "https://$hostname/kvm-admin/v1/organizations/$organization/environments/$environment/keyvaluemaps/$kvmname/entries" \
                    -H "Authorization: Bearer $token" \
                    -H "Content-Type: application/json" \
                    --data "$kvmentry" > /dev/null || ( logfatal "failed to add entry to KVM: https://$hostname/kvm-admin/v1/organizations/$organization/environments/$environment/keyvaluemaps/$kvmname" && exit 1 )
            done
        done
    fi
fi

if [ -d "$temp_folder/apiproxy" ]; then
    loginfo "Configuring API Proxy"

    # Determine Proxy name
    name_in_bundle="$(xmllint --xpath 'string(//APIProxy/@name)' "$temp_folder"/apiproxy/*.xml)"
    bundle_name=${bundle_name:=$name_in_bundle}

    # (optional) Override base path
    if [ -n "$base_path" ]; then
        loginfo "Setting base path: $base_path"
        sed -i.bak "s|<BasePath>.*</BasePath>|<BasePath>$base_path<\/BasePath>|g" "$temp_folder"/apiproxy/proxies/*.xml
        rm "$temp_folder"/apiproxy/proxies/*.xml.bak
    fi

    # (optional) Set Proxy Description
    if [ -n "$description" ]; then
        loginfo "Setting description: $description"
        sed -i.bak "s|^.*<Description>.*</Description>||g" "$temp_folder"/apiproxy/*.xml
        sed -i.bak "s|</APIProxy>|  <Description>$description</Description>\\n</APIProxy>|g" "$temp_folder"/apiproxy/*.xml
        rm "$temp_folder"/apiproxy/*.xml.bak
    fi
elif [ -d "$temp_folder/sharedflowbundle" ]; then
    loginfo "Configuring Shared Flow Bundle"

    api_type="sharedflow"

    shared_flow_name_in_bundle="$(xmllint --xpath 'string(//SharedFlowBundle/@name)' "$temp_folder"/sharedflowbundle/*.xml)"
    bundle_name=${bundle_name:=$shared_flow_name_in_bundle}

        # (optional) Set Proxy Description
    if [ -n "$description" ]; then
        loginfo "Setting description: $description"
        sed -i.bak "s|^.*<Description>.*</Description>||g" "$temp_folder"/sharedflowbundle/*.xml
        sed -i.bak "s|</APIProxy>|  <Description>$description</Description>\\n</APIProxy>|g" "$temp_folder"/sharedflowbundle/*.xml
        rm "$temp_folder"/sharedflowbundle/*.xml.bak
    fi
fi

if [ "$debug" = "T" ]; then
    maven_debug='-X'
fi

if [ "$apiversion" = "google" ]; then
    # install for apigee x/hybrid
    cp "$SCRIPT_FOLDER/pom-hybrid.xml" "$temp_folder/pom.xml"
    (cd "$temp_folder" && mvn install -B ${maven_debug:-} \
        -Dapitype="${api_type:-apiproxy}" \
        -Dorg="$organization" \
        -Denv="$environment" \
        -Dhosturi="$baseuri" \
        -Dproxy.name="$bundle_name" \
        -Dtoken="$token" \
        -Dapigee.options="${deploy_options:-override}" \
        -Dapigee.config.options="${config_action:-none}")
elif [ "$apiversion" = "apigee" ]; then
    # install for apigee Edge
    cp "$SCRIPT_FOLDER/pom-edge.xml" "$temp_folder/pom.xml"
    sed -i.bak "s|<artifactId>.*</artifactId><!--used-by-edge-->|<artifactId>$bundle_name<\/artifactId>|g" "$temp_folder"/pom.xml && rm "$temp_folder"/pom.xml.bak
    (cd "$temp_folder" && mvn install -B ${maven_debug:-} \
        -Dapitype="${api_type:-apiproxy}" \
        -Dorg="$organization" \
        -Denv="$environment" \
        -Dhosturi="$baseuri" \
        -Dproxy.name="$bundle_name" \
        -Dtoken="$token" \
        -Dmfa="$mfa" \
        -Dapigee.options="${deploy_options:-override}" \
        -Dapigee.config.options="${config_action:-none}")
fi
