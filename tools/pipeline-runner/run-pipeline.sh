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

PIPELINE_REPORT=

DIR="${1:-$PWD}"

mkdir -p ./generated/references
mkdir -p ./generated/labs
mkdir -p ./generated/tools

echo "Running under "$DIR

#####
echo "---CHECKING LICENSE HEADERS---"
#####

SRC_FILES=`find $DIR -type f -path "*" | grep -v "node_modules/" | grep -v "generated/" | grep -v ".git/" | grep -v "target/"`
addlicense -check $SRC_FILES
PIPELINE_REPORT="$PIPELINE_REPORT;License Check,$?"

#####
echo "---CHECKING README PROJECT LIST---"
#####

for TYPE in references labs tools; do
  for D in `ls $TYPE`; do
    cat README.md | grep "^-" | grep "$TYPE/$D" -q
    PIPELINE_REPORT="$PIPELINE_REPORT;$TYPE/$D listed in README,$?"
  done
done

#####
echo "---CHECKING CODEOWNERS PROJECT LIST---"
#####

for TYPE in references labs tools; do
  for D in `ls $TYPE`; do
    cat CODEOWNERS | grep "$TYPE/$D" -q
    PIPELINE_REPORT="$PIPELINE_REPORT;$TYPE/$D listed in CODEOWNERS,$?"
  done
done

#####
echo "---JAVA LINTING---"
######

JAVA_FILES=`find $DIR -type f -name "*.java"`
[ ! -z "$JAVAFILES" ] && java -jar /opt/google-java-format.jar --dry-run --set-exit-if-changed $JAVA_FILES
PIPELINE_REPORT="$PIPELINE_REPORT;Java Lint,$?"

#####
echo "---INSTALLING NODE DEPENDENCIES---"
#####

npm i --no-fund --silent

#####
echo "---STARTING MARKDOWN LINTING---"
#####

./node_modules/.bin/remark $DIR -f -r .remarkrc.yml
PIPELINE_REPORT="$PIPELINE_REPORT;Markdown Lint,$?"

#####
echo "---APIGEE JS LINTING---"
#####

APIGEE_JS_FILES=`find $DIR -type f -path "*resources/jsc/*.js"`
./node_modules/.bin/eslint -c .eslintrc-jsc.yml $APIGEE_JS_FILES
PIPELINE_REPORT="$PIPELINE_REPORT;Apigee JS Lint,$?"

#####
echo "---NODE LINTING---"
#####

NODE_JS_FILES=`find . -type f -path "*.js" | grep -v "resources/jsc" | grep -v "node_modules"`
./node_modules/.bin/eslint -c .eslintrc.yml $NODE_JS_FILES
PIPELINE_REPORT="$PIPELINE_REPORT;Node JS Lint,$?"

if test -f "$DIR/pipeline.sh"; then

  #####
  echo "---RUNNING PIPELINE FOR $DIR ONLY---"
  #####

  (cd $DIR && ./pipeline.sh;)
  PIPELINE_REPORT="$PIPELINE_REPORT;$DIR Pipeline,$?"

else
  if [ -z "$APIGEE_USER" -a -z "$APIGEE_PASS" ]; then
    echo "NO CREDENTIALS - SKIPPING PIPELINES"
  else
    for TYPE in references labs tools; do
      for D in `ls $DIR/$TYPE`; do

        #####
        echo "---RUNNING PIPELINE FOR "$TYPE"/$D---"
        #####

        (cd $TYPE/$D && ./pipeline.sh;) 
        PIPELINE_REPORT="$PIPELINE_REPORT;$TYPE/$D Pipeline,$?"
        cp -r ./$TYPE/$D/generated/docs ./generated/$TYPE/$D || echo "NO DOCS FOR $TYPE/$D"

      done
    done
  fi
fi

# print report
echo
echo "FINAL RESULT"
echo "$PIPELINE_REPORT" | tr ";" "\n" | tail -n +2 | awk -F"," '$2 = ($2 > 0 ? "fail" : "pass")' OFS=";" | column -s ";" -t

# set exit code
echo "$PIPELINE_REPORT" | awk -F"," '{ print $2 }' | grep -q "fail"
exit $?

