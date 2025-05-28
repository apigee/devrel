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
    file = sys.argv[1]
    # print("Converting, " + file)
else:
    print("Please provide filename of KVM as an argument.")
    exit(1)

# Open the file in read mode
with open(file, 'r') as file:
    # Load JSON data from the file
    json_data = json.load(file)


# Function to recursively convert "false" strings to False
def convert_false_to_false(json_data):
    if isinstance(json_data, dict):
        for key, value in json_data.items():
            json_data[key] = convert_false_to_false(value)
    elif isinstance(json_data, list):
        for i in range(len(json_data)):
            json_data[i] = convert_false_to_false(json_data[i])
    elif isinstance(json_data, str) and json_data.lower() == 'false':
        return False  # Convert "false" string to false
    return json_data


def convert_true_to_true(json_data):
    if isinstance(json_data, dict):
        for key, value in json_data.items():
            json_data[key] = convert_true_to_true(value)
    elif isinstance(json_data, list):
        for i in range(len(json_data)):
            json_data[i] = convert_true_to_true(json_data[i])
    elif isinstance(json_data, str) and json_data.lower() == 'true':
        return True  # Convert "true" string to true
    return json_data


# Apply the conversion function
json_data = convert_false_to_false(json_data)
json_data = convert_true_to_true(json_data)

# Print the modified JSON
print(json.dumps(json_data, indent=4))
