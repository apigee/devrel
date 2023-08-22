#!/bin/sh

# Copyright 2023 Google LLC
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


echo
echo "This script downloads JAR files and installs them into the local Maven repo."
echo

curl -O https://raw.githubusercontent.com/apigee/api-platform-samples/master/doc-samples/java-cookbook/lib/expressions-1.0.0.jar

 mvn install:install-file \
  -Dfile=expressions-1.0.0.jar \
  -DgroupId=com.apigee.edge \
  -DartifactId=expressions \
  -Dversion=1.0.0 \
  -Dpackaging=jar \
  -DgeneratePom=true

rm expressions-1.0.0.jar 

curl -O https://raw.githubusercontent.com/apigee/api-platform-samples/master/doc-samples/java-cookbook/lib/message-flow-1.0.0.jar

 mvn install:install-file \
  -Dfile=message-flow-1.0.0.jar \
  -DgroupId=com.apigee.edge \
  -DartifactId=message-flow \
  -Dversion=1.0.0 \
  -Dpackaging=jar \
  -DgeneratePom=true

rm message-flow-1.0.0.jar 

echo
echo done.
echo