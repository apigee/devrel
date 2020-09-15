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
DIR="${1:-$PWD}"

npm install -no-fund --silent

# Lint Apigee Javascript Callouts
APIGEE_JS_FILES=$(find "$DIR" -type f -path "*resources/jsc/*.js")
./node_modules/.bin/eslint -c .eslintrc-jsc.yml "$APIGEE_JS_FILES"

# Lint other Node JS
NODE_JS_FILES=$(find . -type f -path "*.js" | grep -v "resources/jsc" | grep -v "node_modules")
./node_modules/.bin/eslint -c .eslintrc.yml "$NODE_JS_FILES"

