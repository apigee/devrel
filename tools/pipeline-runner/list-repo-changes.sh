#!/bin/sh
# Copyright 2021 Google LLC
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

# Helper utility to list all sub-project with changes (excluding .md files)

git fetch origin

git diff --name-only origin/main | \
    grep -v '\.md$' | \
    grep "labs/\|references/\|tools/" | \
    awk -F '/' '{ print $1 "/" $2}' | uniq | paste -sd , -
