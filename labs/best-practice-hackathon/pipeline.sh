#!/bin/sh

# build labs
claat export ./lab.md

# move to generated
cp -r ./best-practices-hackathon ./generated/docs
