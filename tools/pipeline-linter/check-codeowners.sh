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

ERRORS=""

for TYPE in references labs tools; do
  for D in "$TYPE"/*; do
    grep "$D" CODEOWNERS -q || ERRORS="$ERRORS\n[ERROR] missing CODEOWNERS entry for $D"
  done
done

if [ -n "$ERRORS" ]; then
  echo "$ERRORS"
  exit 1
fi
