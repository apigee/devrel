# Copyright 2023 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM debian:11

WORKDIR /app

RUN apt-get update && apt-get install --no-install-recommends -y \
    nodejs=12.22.12~dfsg-1~deb11u4 \
    npm=7.5.2+ds-2 \
    default-jre=2:1.11-72 \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g openapi2apigee@1.2.0
COPY wsdl2apigee-1.0.0-jar-with-dependencies.jar .

ENTRYPOINT ["bash"]

