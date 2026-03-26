# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from unittest.mock import patch
from apigee_config_diff.main import main


def test_main_execution():
    with patch(
        "sys.argv",
        ["main.py", "--commit-before", "HEAD~1", "--current-commit", "HEAD"],
    ), patch(
        "apigee_config_diff.diff.check.detect_changes",
        return_value=([], [], []),
    ), patch(
        "apigee_config_diff.diff.check.write_temporary_files"
    ), patch(
        "apigee_config_diff.diff.process.process_files"
    ):
        main()
