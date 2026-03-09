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

from unittest.mock import patch, MagicMock
from apigee_config_diff.main import main
import os
import json

@patch('sys.argv', ['apigee-config-diff', '--commit-before', 'HEAD~1', '--current-commit', 'HEAD', '--folder', 'resources/', '--output', '/tmp/apigee-single'])
@patch('apigee_config_diff.diff.check.run_command_or_exit')
@patch('apigee_config_diff.diff.check.read_git_file_contents')
@patch('subprocess.run')
def test_single_commit_integration(mock_subprocess_run, mock_read_git_contents, mock_git_ls_files, tmp_path):
    # 1. Mock 'git rev-parse --verify HEAD~1' to FAIL (single commit repo)
    mock_subprocess_run.return_value.returncode = 1
    
    # 2. Mock 'git ls-files' to return some files
    mock_ls_files_result = MagicMock()
    mock_ls_files_result.stdout = "resources/my-org/org/apiProducts.json\npom.xml\n"
    mock_git_ls_files.return_value = mock_ls_files_result
    
    # 3. Mock file contents
    mock_read_git_contents.return_value = '{"name": "my-product"}'
    
    # 4. Run main
    main()
    
    # Verify: pom.xml should be ignored, resources/my-org/org/apiProducts.json should be in update/
    update_file = '/tmp/apigee-single/update/resources/my-org/org/apiProducts.json'
    assert os.path.exists(update_file)
    
    # Verify: pom.xml should NOT be in the update folder
    pom_file = '/tmp/apigee-single/update/pom.xml'
    assert not os.path.exists(pom_file)

    with open(update_file) as f:
        content = json.load(f)
        assert content["name"] == "my-product"
