#!/bin/sh
set -e
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT") 
sh "$SCRIPTPATH"/httpbin-upcheck.sh

