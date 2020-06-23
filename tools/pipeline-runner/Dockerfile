# Copyright 2020 Google LLC
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

FROM golang:alpine

# Install our tools
RUN apk add --no-cache curl git maven nodejs npm openjdk11-jre
RUN go get github.com/google/addlicense
RUN go get github.com/googlecodelabs/tools/claat
RUN curl -sSL \
 https://github.com/google/google-java-format/releases/download/google-java-format-1.8/google-java-format-1.8-all-deps.jar \
  -o /opt/google-java-format.jar

# install our dependencies
ADD run-pipeline.sh /usr/bin/run-pipeline
ADD autofix.sh /usr/bin/autofix

# Run script
WORKDIR /home
CMD run-pipeline
