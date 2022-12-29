#!/bin/sh
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export APIGEE_LIB="$1"
if [ -z "$APIGEE_LIB" ]; then
    echo "No apigee lib directory is provided as an expected argument."
    exit 1
fi


if [ ! -f "$APIGEE_LIB/message-flow-1.0.0.jar" ]; then
    mkdir -p "$APIGEE_LIB"

    curl  --output-dir "$APIGEE_LIB" -LO https://github.com/apigee/api-platform-samples/blob/5b67fe2c3ab23514b67d458a19b63159a2e3f2ab/doc-samples/java-hello/lib/message-flow-1.0.0.jar

    mvn install:install-file -Dfile="$APIGEE_LIB/message-flow-1.0.0.jar" \
    -DgroupId=com.apigee.edge -DartifactId=message-flow -Dversion=1.0.0 -Dpackaging=jar -DgeneratePom=true
fi

if [ ! -f "$APIGEE_LIB/expressions-1.0.0.jar" ]; then
    mkdir -p "$APIGEE_LIB"

    curl  --output-dir "$APIGEE_LIB" -LO https://github.com/apigee/api-platform-samples/blob/5b67fe2c3ab23514b67d458a19b63159a2e3f2ab/doc-samples/java-hello/lib/expressions-1.0.0.jar

    mvn install:install-file -Dfile="$APIGEE_LIB/expressions-1.0.0.jar" \
    -DgroupId=com.apigee.edge -DartifactId=expressions -Dversion=1.0.0 -Dpackaging=jar -DgeneratePom=true
fi
