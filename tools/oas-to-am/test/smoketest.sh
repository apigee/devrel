#!/bin/sh
# Copyright 2021 Google LLC
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
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

# check for dependencies
if ! which xmllint > /dev/null; then
  echo "Please install XML Lint"
fi

RESULT="$(SPEC=$SCRIPTPATH/petstore.json OPERATION=createPets oas-to-am.sh)"

# format xml and remove any licenses before asserting
FORMATTED_RESULT=$(echo "$RESULT" | xmllint --format -)
FORMATTED_EXPECT=$(tr '\n' ' ' < "$SCRIPTPATH/expected.xml" \
  | sed 's/<!--.*-->//' \
  | xmllint --format -)

# assert that the result matches the expected xml
if test "$FORMATTED_RESULT" = "$FORMATTED_EXPECT"; then
  echo "PASS"
else
  echo "FAIL"
fi
