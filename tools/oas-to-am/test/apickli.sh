#!/bin/sh

#Fail on error
set -e

# Grab the paths so this script can be run from anywhere
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

# Set file headers
cat $SCRIPTPATH/features/step_definitions/include.sh

# Grab all the step definitions that we will pass to sed
DEFS=
for D in $SCRIPTPATH/features/step_definitions/*.sed; do
  DEFS="$DEFS -f $D"
done

# 1) Convert our feature file using step_definitions
# 2) Wrap our scenarios in brackets to reduce the scope of variables
cat $SCRIPTPATH/features/*.feature \
  | sed $DEFS \
  | sed '/./{H;$!d} ; x ; s/.*/(&\n)/'
