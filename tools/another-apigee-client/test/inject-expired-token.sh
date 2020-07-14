#!/bin/sh

set -x
set -e

if [ "$1" == "access" ]; then 
  OLD_TOKEN=$(echo "eyJhbGciOiJSUzI1NiJ9."`echo -n '{"exp":1593773053}' | base64`".o8EC22VBvh7Q5S1M3MQLAgMtfoo1OdXC")
  cat /root/.aac/token | jq --arg OLD_TOKEN $OLD_TOKEN '.access_token=$OLD_TOKEN' > /tmp/token
  mv /tmp/token $HOME/.aac/token
elif [ "$1" == "refresh" ]; then
  cp $HOME/aac/test/expired > $HOME/.aac/token
else
  exit 1
done
