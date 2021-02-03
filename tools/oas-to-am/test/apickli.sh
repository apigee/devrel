#!/bin/sh

# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "Licens
# you may not use this file except in compliance with the Lic
# You may obtain a copy of the License at
#
# <http://www.apache.org/licenses/LICENSE-2.0>
#
# Unless required by applicable law or agreed to in writing,
# distributed under the License is distributed on an "AS IS"
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either expres
# See the License for the specific language governing permiss
# limitations under the License.

set -e

# Grab the paths so this script can be run from anywhere
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

# Set file headers
cat "$SCRIPTPATH"/features/step_definitions/include.sh

# Grab all the step definitions that we will pass to sed
DEFS=
for D in "$SCRIPTPATH"/features/step_definitions/*.sed; do
  DEFS="$DEFS -f $D"
done

# 1) Convert our feature file using step_definitions
# 2) Wrap our scenarios in brackets to reduce the scope of variables
cat "$SCRIPTPATH"/features/*.feature \
  | sed "$DEFS" \
  | sed '/./{H;$!d} ; x ; s/.*/(&\n)/'
