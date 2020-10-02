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
RUN apk add --no-cache \
  curl=7.69.1-r1 \
  docker=19.03.12-r0 \
  git=2.26.2-r0 \
  jq=1.6-r1 \
  maven=3.6.3-r0 \
  nodejs=12.18.4-r0 \
  npm=12.18.4-r0 \
  openjdk11-jre-headless=11.0.8_p10-r0 \
  util-linux=2.35.2-r0

RUN go get github.com/google/addlicense
RUN export GO111MODULE=on && go get github.com/googlecodelabs/tools/claat@v2.2.0

# install our dependencies
COPY *.sh /usr/bin/

# Run script
WORKDIR /home
CMD ["run-pipelines.sh"]
