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

for TYPE in references labs tools; do
  # shellcheck disable=SC2045
  for D in $(ls $TYPE); do
    (cd ./$TYPE/"$D" && ./generate-docs.sh;)
    cp -r ./$TYPE/"$D"/generated/docs ./generated/$TYPE/"$D" 2>/dev/null || echo "NO DOCS FOR $TYPE/$D"
  done
done


cat << EOF > ./generated/index.html
<!DOCTYPE html>
<html>
<body>
<script>
(function redirectToDevRelReadme() {
  location.replace("https://github.com/apigee/devrel#apigee-devrel")
})()
</script>
</body>
</html>
EOF