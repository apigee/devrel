#!/bin/bash

# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

encodedkey="$1"
idir="$2"
odir="$3"

    if [ "$#" -lt 3 ]; then
        echo "ERROR: No Key or input folder or output folder is provided."
        echo ""
        echo "    $(basename "$0") <key> <input-folder> <output-folder>"
        echo ""
        exit 5
    fi


key=$(echo "$encodedkey"|base64 -d |hexdump -ve '1/1 "%.2x"')
keylength=$(( $(echo -n "$key" | wc -m) * 8 / 2 ))

odirabs="$(cd "$(dirname "$odir")" || exit; pwd)/$(basename "$odir")"

printf "Source Path: %s\n\n" "$idir"
printf "Full Target Path: %s\n\n" "$odirabs"


mkdir -p "$odir"

(
cd "$idir" || exit
find . | while read -r i; do
  printf "Processing: %s\n" "$i"
  of="$i"
  echo "   of: $of"
  if [ -d "$of" ]; then
    printf "\n   Target DIR: %s\n" "$odirabs/$of"
    mkdir "$odirabs/$of"
  elif [ -f "$of" ]; then
    printf "   Target FILE: %s\n" "$odirabs/$of"
    openssl enc -d -aes-$keylength-ecb -K "$key" -in "$of" > "$odirabs/$of"
  fi

done
)