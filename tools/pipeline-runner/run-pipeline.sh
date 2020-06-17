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

set -e
set -x

REPORT_FAIL=
DIR="${1:-$PWD}"

mkdir -p ./generated/demos
mkdir -p ./generated/labs
mkdir -p ./generated/tools

echo "Running under "$DIR

echo "Checking license headers"
SRC_FILES=`find $DIR -type f -path "*" | grep -v "node_modules" | grep -v "generated"`
addlicense -check $SRC_FILES || REPORT_FAIL=$REPORT_FAIL"LIC "

echo "Java linting"
JAVA_FILES=`find $DIR -type f -name "*.java"`
[ -z "$JAVA_FILES" ] || java -jar /opt/google-java-format.jar --dry-run --set-exit-if-changed $JAVA_FILES || REPORT_FAIL=$REPORT_FAIL"JAVA "

echo "Starting markdown linting"
remark $DIR -f -r .remarkrc.yml || REPORT_FAIL=$REPORT_FAIL"MD "

echo "JS linting"
APIGEE_JS_FILES=`find $DIR -type f -path "*resources/jsc/*.js"`
[ -z "$APIGEE_JS_FILES" ] || eslint -c .eslintrc-jsc.yml $APIGEE_JS_FILES || REPORT_FAIL=$REPORT_FAIL"JS "

NODE_JS_FILES=`find . -type f -path "*.js" | grep -v "resources/jsc" | grep -v "node_modules"`
[ -z "$NODE_JS_FILES" ] || eslint -c .eslintrc.yml $NODE_JS_FILES || REPORT_FAIL=$REPORT_FAIL"NODE "

if test -f "$DIR/pipeline.sh"; then
  # we are running under a single solution
  (cd $DIR && ./pipeline.sh) || REPORT_FAIL=$REPORT_FAIL$D" "
else
  # we are running for the entire devrel
  if [ -z "$APIGEE_USER" -a -z "$APIGEE_PASS" ]; then
    echo "No credentials - skipping pipelines"
  else
    for TYPE in demos labs tools; do
      for D in `ls $DIR/$TYPE`
      do
        echo "Running pipeline on /"$TYPE"/"$D
        (cd ./$TYPE/$D && ./pipeline.sh) || REPORT_FAIL=$REPORT_FAIL$D" "
        cp -r ./$TYPE/$D/generated/docs ./generated/$TYPE/$D || true
      done
    done
  fi
fi

echo "Failures="$REPORT_FAIL

[ -z "$REPORT_FAIL" ] || exit 1
