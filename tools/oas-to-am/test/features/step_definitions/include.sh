#!/bin/sh
# This file is included at the top of the test script. 
# You can extend it

# Fail on error
set -e

trap '[ $? -ne 0 ] && echo "FAIL" || echo "PASS"' EXIT
