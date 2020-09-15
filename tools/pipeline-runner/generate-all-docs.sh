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

rm -rf ./generated

mkdir -p ./generated/references
mkdir -p ./generated/labs
mkdir -p ./generated/tools

cat << EOF > ./generated/index.html
<!DOCTYPE html>
<html>
<head>
  <link rel="stylesheet" href="https://fonts.googleapis.com/icon?family=Material+Icons">
  <link rel="stylesheet" href="https://code.getmdl.io/1.3.0/material.indigo-pink.min.css">
  <script defer src="https://code.getmdl.io/1.3.0/material.min.js"></script>
  <title>Apigee DevRel</title>
  <style>
    body {
      background-color: #f5f5f5 !important
    }

    .doc-content {
      border-radius: 2px;
      padding: 80px 56px;
      margin: 20px 0;
    }

    h1 {
      text-transform: capitalize;
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
    <span class="mdl-layout-title">Apigee DevRel</span>
  </div>
</header>
<div class="mdl-grid mdl-color--grey-100">
  <div class="mdl-cell mdl-cell--1-col mdl-cell--hide-tablet mdl-cell--hide-phone"></div>
  <div class="doc-content mdl-color--white mdl-shadow--4dp content mdl-color-text--grey-800 mdl-cell mdl-cell--10-col">    
EOF

for TYPE in references labs tools; do
  echo "<h2>$TYPE</h2>" >> ./generated/index.html
  echo "<ul>" >> ./generated/index.html
  for D in $(ls $TYPE); do
    (cd ./$TYPE/"$D" && ./generate-docs.sh;)
    cp -r ./$TYPE/"$D"/generated/docs ./generated/$TYPE/"$D"  2>/dev/null || echo "NO DOCS FOR $TYPE/$D"
    if [ -d  ./generated/$TYPE/"$D" ]; then
      echo "<li><a href=\"./$TYPE/$D\">$D</a>" >> ./generated/index.html
    else 
      echo "<li><a href=\"$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/tree/main/$TYPE/$D\">$D</a>" >> ./generated/index.html
    fi
  done
  echo "</ul>" >> ./generated/index.html
done

cat <<'EOF' >> ./generated/index.html
  </div>
</div>
</body>
</html>
EOF
