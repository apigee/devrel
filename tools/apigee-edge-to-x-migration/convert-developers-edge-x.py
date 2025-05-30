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
    developers_file = sys.argv[1]
    # print("Converting, " + developers_file)
else:
    print("Please provide filename for developers.json as an argument.")
    exit(1)

# Open the file in read mode
with open(developers_file, 'r') as file:
    # Load JSON data from the file
    json_data = json.load(file)

# Iterate through developers and convert timestamps
for developer in json_data["developer"]:
    # Convert 'createdAt'
    developer["createdAt"] = str(developer["createdAt"])

    # Convert 'lastModifiedAt'
    developer["lastModifiedAt"] = str(developer["lastModifiedAt"])

    # lowercase 'email'
    developer["email"] = developer["email"].lower()

# Print the modified JSON
print(json.dumps(json_data, indent=4))
