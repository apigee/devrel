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

PIPELINE_REPORT=

DIR="${1:-$PWD}"

repeat() {
  printf "%0.s$1" $(seq 1 $2)
}

stepHeader() {
  set +x
  printf "\n\n$(repeat - 80)\n"
  printf "  $1"
  printf "\n$(repeat - 80)\n"
  set -x
}

runPipeline() {
  #####################################
  stepHeader "Pipeline $1"
  #####################################
  echo "running single pipeline on $1"
  cd $1
  if ./pipeline.sh; then
    PIPELINE_REPORT="$PIPELINE_REPORT PIPELINE,$1,pass"
  else
    PIPELINE_REPORT="$PIPELINE_REPORT PIPELINE,$1,fail"
  fi
  cd $DIR
}



mkdir -p ./generated/references
mkdir -p ./generated/labs
mkdir -p ./generated/tools

echo "Running under "$DIR

#####################################
stepHeader "Checking license headers"
#####################################

SRC_FILES=`find $DIR -type f -path "*" | grep -v "node_modules" | grep -v "generated" | grep -v ".git"`

if addlicense -check $SRC_FILES; then
  PIPELINE_REPORT="LICENSE_CHECK,global,pass"
else
  PIPELINE_REPORT="LICENSE_CHECK,global,fail"
fi

#####################################
stepHeader "Java linting"
#####################################

JAVA_FILES=`find $DIR -type f -name "*.java"`

if [ -z "$JAVA_FILES" ]; then
  PIPELINE_REPORT="$PIPELINE_REPORT JAVA_LINT,global,n/a"
elif java -jar /opt/google-java-format.jar --dry-run --set-exit-if-changed $JAVA_FILES ; then
  PIPELINE_REPORT="$PIPELINE_REPORT JAVA_LINT,global,pass"
else
  PIPELINE_REPORT="$PIPELINE_REPORT JAVA_LINT,global,fail"
fi

#####################################
stepHeader "Installing Node Dependencies"
#####################################
npm i --silent

#####################################
stepHeader "Starting markdown linting"
#####################################

if ./node_modules/.bin/remark $DIR -f -r .remarkrc.yml; then
  PIPELINE_REPORT="$PIPELINE_REPORT MD_LINT,global,pass"
else
  PIPELINE_REPORT="$PIPELINE_REPORT MD_LINT,global,fail"
fi

#####################################
stepHeader "Apigee JS linting"
#####################################

APIGEE_JS_FILES=`find $DIR -type f -path "*resources/jsc/*.js"`

if [ -z "$APIGEE_JS_FILES" ]; then
  PIPELINE_REPORT="$PIPELINE_REPORT APIGEE_JS_LINT,global,n/a"
elif ./node_modules/.bin/eslint -c .eslintrc-jsc.yml $APIGEE_JS_FILES; then
  PIPELINE_REPORT="$PIPELINE_REPORT APIGEE_JS_LINT,global,pass"
else
  PIPELINE_REPORT="$PIPELINE_REPORT APIGEE_JS_LINT,global,fail"
fi

#####################################
stepHeader "NODE linting"
#####################################

NODE_JS_FILES=`find . -type f -path "*.js" | grep -v "resources/jsc" | grep -v "node_modules"`

if [ -z "$NODE_JS_FILES" ]; then
  PIPELINE_REPORT="$PIPELINE_REPORT NODE_JS_LINT,global,n/a"
elif ./node_modules/.bin/eslint -c .eslintrc.yml $NODE_JS_FILES; then
  PIPELINE_REPORT="$PIPELINE_REPORT NODE_JS_LINT,global,pass"
else
  PIPELINE_REPORT="$PIPELINE_REPORT NODE_JS_LINT,global,fail"
fi

if [ test -f "$DIR/pipeline.sh" ]; then
  # we are running under a single solution
  runPipeline $DIR
else
  # we are running for the entire devrel
  if [ -z "$APIGEE_USER" -a -z "$APIGEE_PASS" ]; then
    echo "No credentials - skipping pipelines"
  else
    for TYPE in references labs tools; do
      for D in `ls $DIR/$TYPE`
      do
        echo "Running pipeline on /"$TYPE"/"$D
        runPipeline "./$TYPE/$D"
        cp -r ./$TYPE/$D/generated/docs ./generated/$TYPE/$D || true
      done
    done
  fi
fi


# Check for failure and format results table
set +x
FAILURE_COUNT=0
RED='\033[0;31m'
GREEN='\033[0;92m'
NORMAL='\033[00m'

printf "\n\n"
printf "+$(repeat - 30)+$(repeat - 30)+$(repeat - 10)+\n"
printf "|%-30s|%-30s|%-10s|\n" "Check" "Scope" "Result"
printf "+$(repeat = 30)+$(repeat = 30)+$(repeat = 10)+\n"
for entry in $PIPELINE_REPORT
do
  CHECK_RESULT=$(echo $entry | cut -d "," -f 3)
  STATUS_COLOR=$GREEN
  if [ $CHECK_RESULT = "fail" ]; then 
    FAILURE_COUNT=$((FAILURE_COUNT+1))
    STATUS_COLOR=$RED
  fi
  echo $entry | awk -F ',' "{printf \"|%-30s|%-30s|$STATUS_COLOR%-10s$NORMAL|\\n\",\$1,\$2, \$3}"
  printf "+$(repeat - 30)+$(repeat - 30)+$(repeat - 10)+\n"
done


# Final exit status and message 
if [ "$FAILURE_COUNT" -gt 0 ]; then 
  printf "\n\n$RED$FAILURE_COUNT FAILURE(S) OCCURRED\n"
  exit 1
else
  printf "\n\n${GREEN}SUCCESS${NORMAL}\n"
fi

