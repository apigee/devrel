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

git fetch
PROJECTS=$(git diff --name-only origin/main | grep "labs/\|references/\|tools/" \
  | awk -F '/' '{ print $1 "/" $2}' | uniq)

if [ "$(echo "$PROJECTS" | wc -w)" -le 1 ]; then
  echo "::set-output name=project::$PROJECTS"
else
  1>&2 echo "Please only work on one project per Pull Request"
  exit 1
fi
