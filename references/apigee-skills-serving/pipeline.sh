#!/bin/sh

# Copyright 2026 Google LLC
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

# apigee-skills-serving reference pipeline.
#
# This pipeline runs the hermetic Python test suite. Every HTTP call,
# ADC lookup, and GCP service is mocked, so the pipeline does not need
# a live Apigee org, API hub instance, or GCS bucket.

set -e

SCRIPTPATH="$(
    cd "$(dirname "$0")" || exit >/dev/null 2>&1
    pwd -P
)"

# Install dependencies into an isolated venv.
VENV_PATH="$SCRIPTPATH/venv"
python3 -m venv "$VENV_PATH"
# shellcheck source=/dev/null
. "$VENV_PATH/bin/activate"
pip install --quiet --upgrade pip
pip install --quiet -r "$SCRIPTPATH/requirements.txt"

# Run the test suite from the reference directory so pytest discovers
# the conftest.py path-bootstrap and the bundled fixtures.
cd "$SCRIPTPATH"
python3 -m pytest -q tests/
