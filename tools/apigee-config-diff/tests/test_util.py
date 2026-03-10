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

import pytest
import os
import shutil
import subprocess
from unittest.mock import patch, MagicMock
from apigee_config_diff.diff.util import (
    GitClient,
    create_folder,
    find_resource_type,
    write_to_file,
    run_command_or_exit,
    merge,
)

def test_resolve_commits_normal():
    with patch("subprocess.run") as mock_run:
        mock_run.return_value.returncode = 0
        assert GitClient.resolve_commits("abc", "def") == ("abc", "def")

def test_resolve_commits_zeros():
    # Verifies that zeros always return "" for previous commit
    assert GitClient.resolve_commits("0", "def") == ("", "def")
    assert GitClient.resolve_commits("0000000", "def") == ("", "def")

def test_resolve_commits_single_commit():
    # Simulates single commit scenario where HEAD~1 does not exist
    with patch("subprocess.run") as mock_run:
        mock_run.return_value.returncode = 1
        assert GitClient.resolve_commits("HEAD~1", "HEAD") == ("", "HEAD")

def test_resolve_commits_git_not_found():
    with patch("subprocess.run") as mock_run:
        mock_run.side_effect = FileNotFoundError
        with pytest.raises(SystemExit) as e:
            GitClient.resolve_commits("HEAD", "def")
        assert e.value.code == 1

@patch("apigee_config_diff.diff.util.run_command_or_exit")
def test_read_file_contents(mock_run):
    mock_run.return_value.stdout = "content"
    assert GitClient.read_file_contents("hash", "path") == "content"

@patch("apigee_config_diff.diff.util.run_command_or_exit")
def test_diff_hashes(mock_run):
    GitClient.diff_hashes("a", "b")
    mock_run.assert_called_once_with(['git', 'diff', '--name-status', 'a', 'b'], capture_output=True)

def test_create_folder(tmp_path):
    folder = tmp_path / "test"
    folder.mkdir()
    (folder / "file.txt").write_text("hello")
    
    new_folder = create_folder(str(folder))
    assert os.path.exists(new_folder)
    assert len(os.listdir(new_folder)) == 0

def test_find_resource_type():
    types = ["kvms", "targetServers"]
    assert find_resource_type("kvms.json", types) == "kvms"
    assert find_resource_type("unknown.json", types) is None

def test_write_to_file(tmp_path):
    f_path = tmp_path / "sub" / "test.json"
    content = {"a": 1}
    write_to_file(str(f_path), content)
    assert f_path.exists()
    import json
    with open(f_path) as f:
        assert json.load(f) == content

def test_run_command_or_exit_success():
    # Use a real shell command that will succeed
    res = run_command_or_exit(["echo", "hello"], capture_output=True)
    assert res.stdout.strip() == "hello"
    assert res.returncode == 0

def test_run_command_or_exit_not_found():
    # Command doesn't exist
    with pytest.raises(SystemExit) as e:
        run_command_or_exit(["nonexistent_command_12345"])
    assert e.value.code == 1

def test_run_command_or_exit_fail():
    # Use a python command that prints to stdout, stderr, and then exits 1
    with pytest.raises(SystemExit) as e:
        run_command_or_exit(["python3", "-c", "import sys; print('out'); print('err', file=sys.stderr); sys.exit(1)"], capture_output=True)
    assert e.value.code == 1

def test_merge_primitives():
    assert merge(1, 2) == 2
    assert merge(1, None) == 1
    assert merge(None, 2) == 2

def test_merge_lists():
    assert merge([1], [2]) == [1, 2]

def test_merge_dicts():
    a = {"k1": [1], "k2": {"s1": 1}}
    b = {"k1": [2], "k2": {"s1": 2, "s2": 3}}
    expected = {"k1": [1, 2], "k2": {"s1": 2, "s2": 3}}
    assert merge(a, b) == expected

@patch('apigee_config_diff.diff.util.run_command_or_exit')
def test_list_files(mock_run_command_or_exit):
    mock_run_command_or_exit.return_value = "files"
    result = GitClient.list_files()
    mock_run_command_or_exit.assert_called_once_with(['git', 'ls-files'], capture_output=True)
    assert result == "files"
