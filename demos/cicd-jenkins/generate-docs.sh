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

rm -rf ./generated/docs
mkdir -p ./generated/docs

node_modules/showdown/bin/showdown.js makehtml -i README.md -o ./generated/docs/index.html

mkdir -p ./generated/docs/jenkins
node_modules/showdown/bin/showdown.js makehtml -i ./jenkins/README.md -o ./generated/docs/jenkins/index.html

# fix relative links
sed -i 's/\.\/jenkins\/README.md/\.\/jenkins\/index.html/g' ./generated/docs/index.html

cp -r ./img ./generated/docs/img


wrapHTML() {
cat << EOF > ./generated/docs/tmp.html
<!DOCTYPE html>
<html>
<head>
  <link rel="stylesheet" href="https://fonts.googleapis.com/icon?family=Material+Icons">
  <link rel="stylesheet" href="https://code.getmdl.io/1.3.0/material.indigo-pink.min.css">
  <script defer src="https://code.getmdl.io/1.3.0/material.min.js"></script>
  <style>
    code {
      font-family: monospace;
      padding: 20px;
      background-color: #111;
      display: block;
      color: white;
    }
  </style>
</head>
<body>
$(cat $1)
</body>
</html>
EOF

mv ./generated/docs/tmp.html $1
}

wrapHTML './generated/docs/index.html'
wrapHTML './generated/docs/jenkins/index.html'
