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

rm -rf ./generated/docs
mkdir -p ./generated/docs

npm install --silent --no-fund
node_modules/showdown/bin/showdown.js makehtml -i README.md -o ./generated/docs/index.html

mkdir -p ./generated/docs/jenkins
node_modules/showdown/bin/showdown.js makehtml -i ./jenkins/README.md -o ./generated/docs/jenkins/index.html

# fix relative links
sed -i 's/\.\/jenkins\/README.md/\.\/jenkins\/index.html/g' ./generated/docs/index.html

cp -r ./img ./generated/docs/img


wrapHTML() {

PAGE_TITLE=$(sed -n 's/<h1.*>\(.*\)<\/h1>/\1/Ip' $1)

echo "processed $PAGE_TITLE"

cat << EOF > ./generated/docs/tmp.html
<!DOCTYPE html>
<html>
<head>
  <link rel="stylesheet" href="https://fonts.googleapis.com/icon?family=Material+Icons">
  <link rel="stylesheet" href="https://code.getmdl.io/1.3.0/material.indigo-pink.min.css">
  <script defer src="https://code.getmdl.io/1.3.0/material.min.js"></script>
  <title>$PAGE_TITLE</title>
  <style>
    code {
      font-family: monospace;
      padding: 0 4px;
      background-color: #111;
      color: white;
    }

    code.bash, code.sh {
      display: block;
      padding: 20px;
    }

    .doc-content {
      border-radius: 2px;
      padding: 80px 56px;
      margin: 20px 0;
    }

    h2 {
      font-size: 32px;
      line-height: 36px;
      margin: 24px 0;
    }

    h3 {
      font-size: 22px;
      line-height: 26px;
      margin: 14px 0;
    }

    h4 {
      font-size: 18px;
      line-height: 18px;
    }
  </style>
</head>
<body>
<header class="mdl-layout__header mdl-layout__header--scroll mdl-color--primary-dark mdl-color-text--grey-200">
  <div class="mdl-layout__header-row">
    <span class="mdl-layout-title">$PAGE_TITLE</span>
  </div>
</header>
<div class="mdl-grid mdl-color--grey-100">
  <div class="mdl-cell mdl-cell--1-col mdl-cell--hide-tablet mdl-cell--hide-phone"></div>
  <div class="doc-content mdl-color--white mdl-shadow--4dp content mdl-color-text--grey-800 mdl-cell mdl-cell--10-col">
    $(cat $1)
  </div>
</div>
</body>
</html>
EOF

mv ./generated/docs/tmp.html $1
}

wrapHTML './generated/docs/index.html'
wrapHTML './generated/docs/jenkins/index.html'
