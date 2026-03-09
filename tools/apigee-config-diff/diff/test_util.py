import pytest
import os
import shutil
import subprocess
from unittest.mock import patch, MagicMock
from diff.util import (
    resolve_commits,
    read_git_file_contents,
    git_diff_hashes,
    create_folder,
    find_resource_type,
    write_to_file,
    run_command_or_exit,
    merge
)

def test_resolve_commits_normal():
    assert resolve_commits("abc", "def") == ("abc", "def")

def test_resolve_commits_zeros_head_exists():
    # Mock only the 'git rev-parse' call which resolves HEAD~1
    with patch("subprocess.run") as mock_run:
        mock_run.return_value.returncode = 0
        assert resolve_commits("0000000", "def") == ("HEAD~1", "def")

def test_resolve_commits_zeros_head_not_exists():
    # Mock git returning a failure (no HEAD~1)
    with patch("subprocess.run") as mock_run:
        mock_run.return_value.returncode = 1
        assert resolve_commits("0000000", "def") == ("", "def")

def test_resolve_commits_git_not_found():
    with patch("subprocess.run") as mock_run:
        mock_run.side_effect = FileNotFoundError
        with pytest.raises(SystemExit) as e:
            resolve_commits("0000000", "def")
        assert e.value.code == 1

@patch("diff.util.run_command_or_exit")
def test_read_git_file_contents(mock_run):
    mock_run.return_value.stdout = "content"
    assert read_git_file_contents("hash", "path") == "content"

@patch("diff.util.run_command_or_exit")
def test_git_diff_hashes(mock_run):
    git_diff_hashes("a", "b")
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
