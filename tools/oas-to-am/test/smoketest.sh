#!/bin/sh

set -e
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

# check for dependencies
if ! which xmllint > /dev/null; then
  echo "Please install XML Lint"
fi

RESULT="$(SPEC=$SCRIPTPATH/petstore.json OPERATION=createPets oas-to-am.sh)"

# format xml and remove any licenses before asserting
FORMATTED_RESULT=$(echo "$RESULT" | xmllint --format -)
FORMATTED_EXPECT=$(cat $SCRIPTPATH/expected.xml \
  | tr '\n' ' ' \
  | sed 's/<!--.*-->//' \
  | xmllint --format -)

# assert that the result matches the expected xml
if test "$FORMATTED_RESULT" = "$FORMATTED_EXPECT"; then
  echo "PASS"
else
  echo "FAIL"
fi
