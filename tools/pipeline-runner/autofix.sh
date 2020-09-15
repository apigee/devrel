#!/bin/sh

# Copyright 2020 Google LLC
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# <http://www.apache.org/licenses/LICENSE-2.0>
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -x

DIR="${1:-$PWD}"

echo "This action will edit your local files. Press Ctrl-C and a make a backup or press Enter to continue."
read -r
npm i

# Fix License Files
SRC_FILES=$(find "$DIR" -type f -path "*" | grep -v "node_modules" | grep -v "generated" | grep -v ".git")
addlicense "$SRC_FILES"

# Fix Java Files
JAVA_FILES=$(find "$DIR" -type f -name "*.java")
java -jar /opt/google-java-format.jar -i "$JAVA_FILES"

# Fix Markdown Files
MD_FILES=$(find "$DIR" -type f -path "*.md" | grep -v "node_modules" | grep -v "generated")
./node_modules/.bin/remark "$MD_FILES" -r .remarkrc.yml -o

# Fix JS Files
./node_modules/.bin/eslint --fix -c .eslintrc-jsc.yml "$DIR/**/resources/jsc/*.js"

./node_modules/.bin/eslint --fix -c .eslintrc.yml "$DIR/**/*.js"

# Prettier
npx prettier --write "$DIR"

# Shell
SHELL_FILES=$(find "$DIR" -type f -name "*.sh")
for FILE in $SHELL_FILES; do
  if shellcheck -f quiet "$FILE"; then
    shellcheck -f diff "$FILE" | git -C / apply
  fi
done
