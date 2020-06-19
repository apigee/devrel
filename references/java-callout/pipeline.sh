#!/bin/sh

set -x 
set -e

mvn install -Ptest
npm test --prefix proxy-v1
