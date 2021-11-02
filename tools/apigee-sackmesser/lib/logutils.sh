#!/bin/bash
# shellcheck disable=SC2154
# Copyright 2021 Google LLC
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
RED='\033[0;31m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
NOCOL='\033[0m'

logdebug() {
    if [ "$debug" = "T" ]; then
        log "DEBUG" "$@" "$BLUE"
    fi
}
loginfo() {
    log "INFO" "$@" "$NOCOL"
}
logwarn() {
    log "WARN" "$@" "$ORANGE"
}
logerror() {
    log "ERROR" "$@" "$RED"
}
logfatal() {
    log "FATAL" "$@" "$RED"
}

log() {
    echo -e "${3}[$1] $2${NOCOL}" 1>&2;
}