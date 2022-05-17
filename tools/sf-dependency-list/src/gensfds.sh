#!/usr/bin/env bash

# Copyright 2022 Google LLC
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

# directory with shared flows
sfdir="$1"
target=$2

if [ -z "$sfdir" ]; then
  echo "ERROR: Missing directory with shared flows"
  exit 1
fi
if [ ! -d "$sfdir" ]; then
  echo "ERROR: Argument $sfdir is not a  directory"
  exit 1
fi

# either dot or tsort
if [ -z "$target" ]; then
  echo "ERROR: Missing argument target type: dot or tsort"
  exit 1
fi
# TODO: [ ] check for valid value


cd "$sfdir" || exit

if [ "$target" = "dot" ]; then

  echo "digraph G {"
  echo "  rankdir=LR"
  echo "  node [shape=box,fixedsize=true,width=3]"
fi

if [ "$target" = "tsort" ]; then

    dag=""

    declare -a orphans=()
    declare -A visited
fi

for sf in */; do

  sflow="${sf::-1}"

  # check for structural integrity
  if [ ! -e "${sf}sharedflowbundle/policies" ];then
     echo "ERROR: $sf directory is not a shared flow file structure. Missing: ${sf}sharedflowbundle/policies"
     exit 1
  fi

  pushd "${sf}sharedflowbundle/policies" > /dev/null || exit

if [ "$target" = "dot" ]; then

  list=$(grep -Ril "<FlowCallout " $(ls))
  if [ -z "$list" ];then
    printf "  \"%s\";\n" "$sflow"
  else
    for fc in $list; do
      printf "  \"%s\" ->" "$sflow"

      grep '<SharedFlowBundle' "$fc" | awk -F "[><]" '{print" \"" $3 "\";"}'
     done
  fi
fi

if [ "$target" = "tsort" ]; then
  list=$(grep -Ril "<FlowCallout " $(ls))
  if [ -z "$list" ];then
          orphans+=("$sflow")
  else
    for fc in $list; do
      to="$(grep '<SharedFlowBundle' "$fc" | awk -F "[><]" '{print $3 "" }')"
      visited[$to]=true
      dag="$dag$sflow $to"$'\n'
    done
  fi


fi
  popd > /dev/null || exit

done

if [ "$target" = "dot" ]; then
  echo "}"
fi

if [ "$target" = "tsort" ]; then
    echo -n "$dag"|tsort|tac

    for sf in "${orphans[@]}"; do
      if [ ! "${visited[$sf]}" ]; then
        echo "$sf"
      fi
    done
fi
