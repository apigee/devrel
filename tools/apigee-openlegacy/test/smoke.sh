#!/bin/sh
set -e 
set -x

test "$(./bin/apigee-openlegacy)" = "Success"
