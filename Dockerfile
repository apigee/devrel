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

FROM debian:stable

WORKDIR /home

RUN apt-get update
RUN apt-get install -y curl golang openjdk-11-jre git
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -
RUN apt-get install -y nodejs

RUN mkdir -p tools/go
RUN mkdir -p tools/java

ENV GOPATH /home/tools/go
RUN go get github.com/googlecodelabs/tools/claat
RUN go get github.com/google/addlicense

RUN (cd tools/java && curl -sSL https://github.com/google/google-java-format/releases/download/google-java-format-1.8/google-java-format-1.8-all-deps.jar -O)

#USER devrel
#ADD --chown=devrel . /home/devrel/src
ADD . /home/src

WORKDIR src
CMD ./run-pipeline.sh
