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


set -e
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

if [ "$1" == "access" ]; then 
  OLD_TOKEN=$(echo "eyJhbGciOiJSUzI1NiJ9."$(echo -n '{"exp":1593773053}' | base64)".o8EC22VBvh7Q5S1M3MQLAgMtfoo1OdXC")
  cat /root/.aac/token | jq --arg OLD_TOKEN "$OLD_TOKEN" '.access_token=$OLD_TOKEN' > /tmp/token
  mv /tmp/token "$HOME"/.aac/token
elif [ "$1" == "refresh" ]; then
  cp "$SCRIPTPATH"/expired "$HOME"/.aac/token
else
  exit 1
fi
