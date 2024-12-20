# Copyright 2024 Google LLC
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

FROM google/cloud-sdk:alpine AS gcloud-sdk

FROM alpine:3.21

COPY --from=gcloud-sdk /google-cloud-sdk /google-cloud-sdk
ENV PATH="/google-cloud-sdk/bin:${PATH}"

# Install additional tools
RUN apk add --no-cache \
  bash \
  docker \
  git \
  curl \
  jq \
  libxml2-utils \
  maven \
  nodejs \
  npm \
  openjdk11-jre-headless \
  openssl \
  util-linux \
  coreutils \
  gettext \
  # add chromium and dependencies for UI testing
  chromium \
  nss \
  freetype \
  freetype-dev \
  harfbuzz \
  ca-certificates \
  ttf-freefont \
  py-pip \
  zip \
  make \
  go \
  yq \
  protobuf-dev

# Reduce nighly log (note: -ntp requires maven 3.6.1+)
RUN mv /usr/bin/mvn /usr/bin/_mvn &&\
  printf '#!/bin/bash\n/usr/bin/_mvn -ntp "$@"' > /usr/bin/mvn && \
  chmod +x /usr/bin/mvn

# install claat
RUN wget -qO- https://github.com/googlecodelabs/tools/releases/download/v2.2.6/claat-linux-amd64 > /usr/local/bin/claat
RUN chmod +x /usr/local/bin/claat

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
  PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

RUN npm install --global puppeteer@5.2.1 apigeelint@2.10.0

# add our tooling scripts
COPY *.sh /usr/bin/

# Run script
WORKDIR /home
CMD ["run-pipelines.sh"]
