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

# Ensures that all sub-projects in this repository are listed
# in the README file in the root of the repository.

set -e

ERRORS=""

for TYPE in references labs tools; do
  for D in "$TYPE"/*; do
    grep "^-" README.md | grep "$D" -q || ERRORS="$ERRORS\n[ERROR] missing root README entry for $D"
  done
done

if [ -n "$ERRORS" ]; then
  echo "$ERRORS"
  exit 1
fi
