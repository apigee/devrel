#!python3

# Copyright 2023 Google LLC
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
# limitations under the License.import json

import json
import sys

if len(sys.argv) > 1:
    kvm_file = sys.argv[1]
    # print("Converting, " + kvm_file)
else:
    print("Please provide filename of KVM as an argument.")
    exit(1)


# Open the file in read mode
with open(kvm_file, 'r') as file:
    # Load JSON data from the file
    json_data = json.load(file)

# Create a new array to store the copied objects
keyValueEntries = []

# Iterate over each object in the "entry" array and copy it to the new array
for entry in json_data['entry']:
    keyValueEntries.append(entry)

# Add the new "keyValueEntries" array to the data
json_data['keyValueEntries'] = keyValueEntries
json_data.pop('entry')

# Print the modified JSON
print(json.dumps(json_data, indent=4))
