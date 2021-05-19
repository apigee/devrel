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

FROM google/cloud-sdk:alpine

# Install additional tools
RUN apk add --no-cache \
  jq \
  libxml2-utils \
  maven \
  nodejs \
  npm \
  openjdk11-jre-headless \
  openssl \
  util-linux \
  # add chromium and dependencies for UI testing
  chromium \
  nss \
  freetype \
  freetype-dev \
  harfbuzz \
  ca-certificates \
  ttf-freefont

# install claat
RUN wget -qO- https://github.com/googlecodelabs/tools/releases/download/v2.2.4/claat-linux-amd64 > /usr/local/bin/claat
RUN chmod +x /usr/local/bin/claat

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

RUN npm install --global puppeteer@5.2.1

# add our tooling scripts
COPY *.sh /usr/bin/

# Run script
WORKDIR /home
CMD ["run-pipelines.sh"]
