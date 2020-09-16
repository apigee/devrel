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

###
# we will fail on error once all projects pass these new checks
###
#set -e 

echo "DevRel - Shell Check"

DIR="${1:-$PWD}"

SHELL_FILES=$(find "$DIR" -type f -path "*.sh")
for FILE in $SHELL_FILES; do
  shellcheck "$FILE"
done
