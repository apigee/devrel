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

# This file is included at the top of the test script. 
# You can extend it

# Fail on error
set -e

trap '[ $? -ne 0 ] && echo "FAIL" || echo "PASS"' EXIT
