#!/bin/sh

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

set -e
set -x 

DIR="${1:-$PWD}"

read -p "This action will edit your local files. Press Ctrl-C and a make a backup or press Enter to continue."

# Fix License Files
SRC_FILES=`find $DIR -type f -path "*" | grep -v "node_modules" | grep -v "generated"`
addlicense $SRC_FILES

# Fix Markdown Files
SRC_FILES=`find $DIR -type f -path "*.md" | grep -v "node_modules" | grep -v "generated"`
remark $SRC_FILES -r .remarkrc.yml -o

# Fix JS Files
APIGEE_JS_FILES=`find $DIR -type f -path "*resources/jsc/*.js"`
[ -z "$APIGEE_JS_FILES" ] || eslint --fix -c .eslintrc-jsc.yml $APIGEE_JS_FILES

NODE_JS_FILES=`find . -type f -path "*.js" | grep -v "resources/jsc" | grep -v "node_modules"`
[ -z "$NODE_JS_FILES" ] || eslint --fix -c .eslintrc.yml $NODE_JS_FILES
