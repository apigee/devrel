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

FROM golang:alpine3.12

# Install our tools
RUN apk add --no-cache \
  curl \
  docker \
  git \
  jq \
  maven \
  nodejs \
  npm \
  openjdk11-jre-headless \
  util-linux \
  # add chromium and dependencies for UI testing
  chromium \
  nss \
  freetype \
  freetype-dev \
  harfbuzz \
  ca-certificates \
  ttf-freefont

RUN go get github.com/google/addlicense
RUN export GO111MODULE=on && go get github.com/googlecodelabs/tools/claat@v2.2.0

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

RUN npm install --global puppeteer@5.2.1

# install our dependencies
COPY *.sh /usr/bin/

# Run script
WORKDIR /home
CMD ["run-pipelines.sh"]
