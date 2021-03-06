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

REPORT=$(cat <<EOF
### Pipeline Report
\`\`\`
$buildresult
\`\`\`

[View details in Cloud Build (permission required)](https://console.cloud.google.com/cloud-build/builds/$BUILD_ID?project=$PROJECT_ID)

Commit version: $SHORT_SHA
EOF
)

REPO_API="https://api.github.com/repos/$REPO_GH_ISSUE"

createIssueComment() {
  COMMENTS_URL=$1
  REPORT=$2

  curl \
    -X POST \
    -u "$GH_BOT_NAME:$GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$COMMENTS_URL" \
    -d "{\"body\":$(echo "$REPORT" | jq -sR)}"
}

previousIssueComments() {
  curl \
    -X GET \
    -u "$GH_BOT_NAME:$GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$REPO_API/issues?state=open&creator=$GH_BOT_NAME" | jq -r '.[] | select(.title == "Nightly build failure") | .comments_url'
}

createIssue() {
  TITLE=$1
  REPORT=$2

  curl \
    -X POST \
    -u "$GH_BOT_NAME:$GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$REPO_API/issues$ISSUE_COMMENTS" \
    -d "{\"title\":\"$TITLE\",\"body\":$(echo "$REPORT" | jq -sR)}"
}

if [ -n "$PR_NUMBER" ]; then
  # Always comment on PR builds
  createIssueComment "$REPO_API/issues/$PR_NUMBER/comments" "$REPORT"
elif echo "$buildresult" | grep -q "fail" && [ "$CREATE_GH_ISSUE" = "true" ]; then
  PREVIOUS_ISSUE_COMMENTS=$(previousIssueComments)
  if [ -n "$PREVIOUS_ISSUE_COMMENTS" ]; then
    # There is already an issue for a failing build
    createIssueComment "$PREVIOUS_ISSUE_COMMENTS" "$REPORT"
  else
    # Create a new issue
    createIssue "Nightly build failure" "$REPORT"
  fi
else
  echo "[INFO] No issue created"
  echo "$buildresult"
fi
