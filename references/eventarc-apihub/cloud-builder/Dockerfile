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

RUN apt update
RUN apt install nodejs npm -y
RUN npm install -g openapi2apigee
RUN apt install default-jre -y

COPY wsdl2apigee-1.0.0-jar-with-dependencies.jar .
ENTRYPOINT ["bash"]

