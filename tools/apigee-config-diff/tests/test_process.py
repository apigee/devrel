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

import os
import subprocess
import pytest
from unittest.mock import patch, MagicMock
from apigee_config_diff.diff.process import process_files

def test_process_files_dry_run(tmp_path, capsys):
    # Create a mock structure
    # update/resources/org1/env/dev/file.json
    # update/resources/org1/org/file.json
    update_dir = tmp_path / "update" / "resources"
    update_dir.mkdir(parents=True)
    (update_dir / "org1").mkdir()
    (update_dir / "org1" / "env").mkdir()
    (update_dir / "org1" / "env" / "dev").mkdir()
    (update_dir / "org1" / "env" / "dev" / "test.json").write_text("{}")
    (update_dir / "org1" / "org").mkdir()
    (update_dir / "org1" / "org" / "products.json").write_text("{}")
    
    with patch("subprocess.run") as mock_run:
        process_files(str(tmp_path), "resources", confirm=False)
        mock_run.assert_called_with(["tree", str(update_dir)], check=False)
        out, _ = capsys.readouterr()
        assert "Affected Orgs and Environments" in out
        assert "Org: org1, Envs: ['dev']" in out
        assert "[Dry Run]" in out
        
def test_process_files_confirm_env(tmp_path):
    update_dir = tmp_path / "update" / "resources"
    update_dir.mkdir(parents=True)
    (update_dir / "org1" / "env" / "prod").mkdir(parents=True)
    (update_dir / "org1" / "env" / "prod" / "test.json").write_text("{}")
    
    with patch("subprocess.run") as mock_run:
        process_files(str(tmp_path), "resources", confirm=True)
        # Should call mvn install for prod env
        mock_run.assert_called()
        args, kwargs = mock_run.call_args
        cmd = args[0]
        assert "mvn" in cmd
        assert "-Porg1" in cmd
        assert "-Dapigee.env=prod" in cmd
        assert "-Dapigee.org=org1" in cmd

def test_process_files_confirm_no_env(tmp_path):
    update_dir = tmp_path / "update" / "resources"
    update_dir.mkdir(parents=True)
    (update_dir / "org1" / "org").mkdir(parents=True)
    (update_dir / "org1" / "org" / "products.json").write_text("{}")
    
    with patch("subprocess.run") as mock_run:
        process_files(str(tmp_path), "resources", confirm=True)
        # Should call mvn install for org level
        mock_run.assert_called()
        args, kwargs = mock_run.call_args
        cmd = args[0]
        assert "mvn" in cmd
        assert "-Porg1" in cmd
        assert "-Dapigee.org=org1" in cmd
        assert not any("-Dapigee.env=" in arg for arg in cmd)

def test_process_files_mvn_fail(tmp_path):
    update_dir = tmp_path / "update" / "resources"
    update_dir.mkdir(parents=True)
    (update_dir / "org1" / "org").mkdir(parents=True)
    (update_dir / "org1" / "org" / "products.json").write_text("{}")
    
    with patch("subprocess.run") as mock_run:
        mock_run.side_effect = subprocess.CalledProcessError(1, ["mvn"])
        with pytest.raises(SystemExit) as e:
            process_files(str(tmp_path), "resources", confirm=True)
        assert e.value.code == 1

def test_process_files_no_files(tmp_path, capsys):
    (tmp_path / "update").mkdir()
    process_files(str(tmp_path), "resources", confirm=False)
    out, _ = capsys.readouterr()
    assert "No files found in" in out
    assert "(subfolder empty)." in out

def test_process_files_empty_action_dir(tmp_path, capsys):
    (tmp_path / "update" / "resources").mkdir(parents=True)
    process_files(str(tmp_path), "resources", confirm=False)
    out, _ = capsys.readouterr()
    assert "No files to process for update." in out

def test_process_files_mvn_fail_env(tmp_path):
    update_dir = tmp_path / "update" / "resources"
    update_dir.mkdir(parents=True)
    (update_dir / "org1" / "env" / "dev").mkdir(parents=True)
    (update_dir / "org1" / "env" / "dev" / "test.json").write_text("{}")
    
    with patch("subprocess.run") as mock_run:
        mock_run.side_effect = subprocess.CalledProcessError(1, ["mvn"])
        with pytest.raises(SystemExit) as e:
            process_files(str(tmp_path), "resources", confirm=True)
        assert e.value.code == 1

def test_process_files_tree_not_found(tmp_path, capsys):
    update_dir = tmp_path / "update" / "resources"
    update_dir.mkdir(parents=True)
    (update_dir / "org1" / "org").mkdir(parents=True)
    (update_dir / "org1" / "org" / "products.json").write_text("{}")
    
    with patch("subprocess.run") as mock_run:
        mock_run.side_effect = FileNotFoundError
        process_files(str(tmp_path), "resources", confirm=False)
        out, _ = capsys.readouterr()
        # Verify the fallback printing when tree is not found
        assert "products.json" in out

def test_process_files_edge_cases(tmp_path, capsys):
    # 1. No orgs/environments found
    (tmp_path / "update" / "resources").mkdir(parents=True)
    (tmp_path / "update" / "resources" / "invalid").write_text("{}")
    process_files(str(tmp_path), "resources", confirm=False)
    out, _ = capsys.readouterr()
    assert "No orgs/environments found." in out
    
    # 2. empty org_env_map coverage
    with patch("os.walk") as mock_walk:
        mock_walk.return_value = [(str(tmp_path / "update" / "resources"), [], ["file.json"])]
        process_files(str(tmp_path), "resources", confirm=False)
        out2, _ = capsys.readouterr()
        assert "No orgs/environments found." in out2

def test_process_files_auth_args(tmp_path):
    update_dir = tmp_path / "update" / "resources"
    update_dir.mkdir(parents=True)
    (update_dir / "org1" / "org").mkdir(parents=True)
    (update_dir / "org1" / "org" / "products.json").write_text("{}")
    
    with patch("subprocess.run") as mock_run:
        process_files(str(tmp_path), "resources", confirm=True, bearer="mytoken", sa_path="mysa.json")
        mock_run.assert_called()
        args, _ = mock_run.call_args
        cmd = args[0]
        assert "-Dapigee.bearer=mytoken" in cmd
        assert "-Dapigee.serviceaccount.file=mysa.json" in cmd

def test_process_files_auth_args_partial(tmp_path):
    update_dir = tmp_path / "update" / "resources"
    update_dir.mkdir(parents=True)
    (update_dir / "org1" / "env" / "dev").mkdir(parents=True)
    (update_dir / "org1" / "env" / "dev" / "test.json").write_text("{}")
    with patch("subprocess.run") as mock_run:
        process_files(str(tmp_path), "resources", confirm=True, bearer="mytoken")
        assert "-Dapigee.bearer=mytoken" in mock_run.call_args[0][0]
        assert not any("-Dapigee.serviceaccount.file=" in x for x in mock_run.call_args[0][0])
