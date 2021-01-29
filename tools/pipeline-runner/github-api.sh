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
buildresult=$(cat)

COMMENT=$(cat <<EOF
### Pipeline Report
\`\`\`
$buildresult
\`\`\`

[view details in Cloud Build (permission required)](https://console.cloud.google.com/cloud-build/builds/$BUILD_ID?project=$PROJECT_ID)
EOF
)

REPO_API="https://api.github.com/repos/$REPO_GH_ISSUE"

if [ -n "$PR_NUMBER" ]; then ## always comment on PR builds
  curl \
    -X POST \
    -u apigee-devrel-bot:"$GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$REPO_API/issues/$PR_NUMBER/comments" \
    -d "{\"body\":$(echo "$COMMENT" | jq -sR)}"
elif echo "$buildresult" | grep -q "fail" && [ "$CREATE_GH_ISSUE" = "true" ]; then
  curl \
    -X POST \
    -u apigee-devrel-bot:"$GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$REPO_API/issues$ISSUE_COMMENTS" \
    -d "{\"title\":\"Nighly build failure\",\"body\":$(echo "$COMMENT" | jq -sR)}"
else
  echo "[INFO] No issue created"
  echo "$buildresult"
fi
