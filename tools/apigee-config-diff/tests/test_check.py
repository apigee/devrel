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
import os

from apigee_config_diff.diff.check import detect_changes, write_temporary_files

@patch('apigee_config_diff.diff.check.GitClient.diff_hashes')
def test_detect_changes_with_previous_commit(mock_git_diff_hashes):
    mock_result = MagicMock()
    mock_result.stdout = (
        "M\tresources/file1.json\n"
        "A\tresources/file2.json\n"
        "D\tresources/file3.json\n"
        "R100\tresources/old_name.json\tresources/new_name.json\n"
        "M\tother/ignored.txt"
    )
    mock_git_diff_hashes.return_value = mock_result

    previous_commit = "abc1234"
    current_commit = "def5678"
    resources_base_path = "resources/"

    added, deleted, modified = detect_changes(previous_commit, current_commit, resources_base_path)

    assert "resources/file2.json" in added
    assert "resources/new_name.json" in added
    assert "resources/file3.json" in deleted
    assert "resources/old_name.json" in deleted
    assert "resources/file1.json" in modified
    assert "other/ignored.txt" not in (added + deleted + modified)
    assert len(added) == 2
    assert len(deleted) == 2
    assert len(modified) == 1

@patch('apigee_config_diff.diff.check.GitClient.list_files')
def test_detect_changes_initial_commit(mock_run_command_or_exit):
    mock_result = MagicMock()
    mock_result.stdout = (
        "resources/file1.json\n"
        "resources/file2.json\n"
        "resources/file3.json"
    )
    mock_run_command_or_exit.return_value = mock_result

    previous_commit = None
    current_commit = "def5678"
    resources_base_path = "resources/"

    added, deleted, modified = detect_changes(previous_commit, current_commit, resources_base_path)

    assert "resources/file1.json" in added
    assert "resources/file2.json" in added
    assert "resources/file3.json" in added
    assert len(added) == 3
    assert len(deleted) == 0
    assert len(modified) == 0

@patch('apigee_config_diff.diff.check.write_to_file')
@patch('apigee_config_diff.diff.check.GitClient.read_file_contents')
@patch('apigee_config_diff.diff.check.create_folder')
@patch('apigee_config_diff.diff.check.find_resource_type')
@patch('apigee_config_diff.diff.check.diff')
@patch.dict('apigee_config_diff.diff.check.RESOURCES_ID', {"some_type": "key"})
def test_write_temporary_files_basic(mock_diff_func, mock_find_resource_type, mock_create_folder, mock_read_git_contents, mock_write_to_file):
    mock_create_folder.side_effect = lambda x: x
    mock_read_git_contents.return_value = "{}"
    mock_find_resource_type.return_value = "some_type"
    mock_diff_elements = {
        "added": [{"name": "new_item_from_diff"}],
        "modified": [{"name": "mod_item_from_diff"}],
        "deleted": [{"name": "del_item_from_diff"}]
    }
    mock_diff_func.return_value = mock_diff_elements

    added_files = ["resources/newly_added_file.json"]
    deleted_files = ["resources/to_be_deleted_file.json"]
    modified_files = ["resources/modified_file.json"]
    previous_commit = "abc1234"
    current_commit = "def5678"
    tmp_base_path = "/tmp/test_output"

    update_folder_path = os.path.join(tmp_base_path, "update")
    delete_folder_path = os.path.join(tmp_base_path, "delete")

    write_temporary_files(added_files, deleted_files, modified_files, previous_commit, current_commit, tmp_base_path)

    mock_create_folder.assert_any_call(update_folder_path)
    mock_create_folder.assert_any_call(delete_folder_path)

    path_for_added_file = os.path.join(update_folder_path, "resources/newly_added_file.json")
    mock_read_git_contents.assert_any_call(current_commit, "resources/newly_added_file.json")
    mock_write_to_file.assert_any_call(path_for_added_file, {})

    path_for_deleted_file = os.path.join(delete_folder_path, "resources/to_be_deleted_file.json")
    mock_read_git_contents.assert_any_call(previous_commit, "resources/to_be_deleted_file.json")
    mock_write_to_file.assert_any_call(path_for_deleted_file, {})

    mod_f_path = "resources/modified_file.json"
    mock_read_git_contents.assert_any_call(previous_commit, mod_f_path)
    mock_read_git_contents.assert_any_call(current_commit, mod_f_path)
    mock_diff_func.assert_any_call({}, {}, "key")

    expected_content_for_update_from_mod = mock_diff_elements['added'] + mock_diff_elements['modified']
    path_for_mod_update = os.path.join(update_folder_path, mod_f_path)
    mock_write_to_file.assert_any_call(path_for_mod_update, expected_content_for_update_from_mod)

    path_for_mod_delete = os.path.join(delete_folder_path, f"{mod_f_path}.delete")
    mock_write_to_file.assert_any_call(path_for_mod_delete, mock_diff_elements['deleted'])

@patch('apigee_config_diff.diff.check.write_to_file')
@patch('apigee_config_diff.diff.check.GitClient.read_file_contents')
@patch('apigee_config_diff.diff.check.create_folder')
@patch('apigee_config_diff.diff.check.find_resource_type')
@patch('apigee_config_diff.diff.check.diff')
@patch.dict('apigee_config_diff.diff.check.RESOURCES_ID', {"developerApps": "name"})
def test_write_temporary_files_dict_merge_logic(mock_diff_func, mock_find_resource_type, mock_create_folder, mock_read_git_contents, mock_write_to_file):
    mock_create_folder.side_effect = lambda x: x
    mock_read_git_contents.return_value = "{}"
    mock_find_resource_type.return_value = "developerApps"
    
    # Simulate the "overlapping key" scenario where dev@example.com has an added AND modified app
    mock_diff_elements = {
        "added": {
            "dev@example.com": [{"name": "App_B"}]
        },
        "modified": {
            "dev@example.com": [{"name": "App_A"}]
        },
        "deleted": {}
    }
    mock_diff_func.return_value = mock_diff_elements

    modified_files = ["resources/developerApps.json"]
    tmp_base_path = "/tmp/test_output"
    update_folder_path = os.path.join(tmp_base_path, "update")

    write_temporary_files([], [], modified_files, "prev", "curr", tmp_base_path)

    expected_merged_content = {
        "dev@example.com": [{"name": "App_B"}, {"name": "App_A"}]
    }
    
    path_for_mod_update = os.path.join(update_folder_path, "resources/developerApps.json")
    
    # Verify that the merged content contains BOTH apps, not just the last one
    mock_write_to_file.assert_any_call(path_for_mod_update, expected_merged_content)

@patch('apigee_config_diff.diff.check.GitClient.diff_hashes')
def test_detect_changes_edge_cases(mock_git_diff_hashes):
    mock_result = MagicMock()
    mock_result.stdout = (
        "R100\tresources/old_rename.json\n" # Missing path_new
        "C075\tresources/copied_fail.json\n" # Missing path_new
        "X\tresources/unknown.json\n" # Unknown status
        "C075\tresources/old.json\tresources/new.json" # Valid copy
    )
    mock_git_diff_hashes.return_value = mock_result

    added, deleted, modified = detect_changes("a", "b", "resources")
    
    assert "resources/new.json" in added
    assert len(added) == 1
    assert len(deleted) == 0
    
    # Test unknown status and path_new is None warnings (implicitly covered by calling detect_changes with these mocks)
    # We can also check if they don't crash
    # The current code prints to stderr
    detect_changes("a", "b", "resources/")

@patch('apigee_config_diff.diff.check.write_to_file')
@patch('apigee_config_diff.diff.check.GitClient.read_file_contents')
@patch('apigee_config_diff.diff.check.create_folder')
@patch('apigee_config_diff.diff.check.find_resource_type')
def test_write_temporary_files_unknown_type(mock_find_resource_type, mock_create_folder, mock_read_git_contents, mock_write_to_file):
    mock_create_folder.side_effect = lambda x: x
    mock_read_git_contents.return_value = '{"full": "content"}'
    mock_find_resource_type.return_value = None
    
    modified_files = ["resources/unknown.json"]
    write_temporary_files([], [], modified_files, "prev", "curr", "/tmp")
    
    mock_write_to_file.assert_any_call("/tmp/update/resources/unknown.json", {"full": "content"})

@patch('apigee_config_diff.diff.check.GitClient.list_files')
def test_detect_changes_initial_commit_no_files(mock_run_command_or_exit):
    mock_result = MagicMock()
    mock_result.stdout = ""
    mock_run_command_or_exit.return_value = mock_result

    added, deleted, modified = detect_changes(None, "def5678", "resources/")
    assert len(added) == 0

@patch('apigee_config_diff.diff.check.GitClient.list_files')
def test_detect_changes_initial_commit_empty_line(mock_run_command_or_exit):
    mock_result = MagicMock()
    mock_result.stdout = "\n"
    mock_run_command_or_exit.return_value = mock_result

    added, deleted, modified = detect_changes(None, "def5678", "resources/")
    assert len(added) == 0

@patch('apigee_config_diff.diff.check.write_to_file')
@patch('apigee_config_diff.diff.check.GitClient.read_file_contents')
@patch('apigee_config_diff.diff.check.create_folder')
@patch('apigee_config_diff.diff.check.find_resource_type')
@patch('apigee_config_diff.diff.check.diff')
@patch.dict('apigee_config_diff.diff.check.RESOURCES_ID', {"some_type": "key"})
def test_write_temporary_files_empty_diff(mock_diff_func, mock_find_resource_type, mock_create_folder, mock_read_git_contents, mock_write_to_file):
    mock_create_folder.side_effect = lambda x: x
    mock_read_git_contents.return_value = "{}"
    mock_find_resource_type.return_value = "some_type"
    mock_diff_func.return_value = {"added": [], "modified": [], "deleted": []}
    
    write_temporary_files([], [], ["resources/file.json"], "prev", "curr", "/tmp")
    # write_to_file should NOT be called for update/delete if they are empty
    assert mock_write_to_file.call_count == 0
