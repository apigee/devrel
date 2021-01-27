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

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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


key=$(echo $encodedkey|base64 -d |hexdump -ve '1/1 "%.2x"')
keylength=$(( $(echo -n $K | wc -m) / 2 * 8 ))

odirabs="$(cd "$(dirname "$odir")"; pwd)/$(basename "$odir")"

printf "Source Path: $idir\n\n"
printf "Full Target Path: $odirabs\n\n"


mkdir -p $odir

(
cd $idir
find . | while read i; do
  echo "Processing: $i\n"
  of="$i"
  echo "   of: $of"
  if [ -d "$of" ]; then
    printf "\n   Target DIR: $odirabs/$of\n"
    mkdir "$odirabs/$of"
  elif [ -f "$of" ]; then
    printf "   Target FILE: $odirabs/$of\n"
    openssl enc -d -aes-$keylength-ecb -K $key -in "$of" > "$odirabs/$of"
  fi

done
)