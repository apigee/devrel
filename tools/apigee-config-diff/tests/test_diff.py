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
from apigee_config_diff.diff.diff import _transform_identification, diff


def test_identify_object():
    input_data = [
        {"id": 1, "val": 11},
        {"id": 2, "val": 22},
        {"id": 3, "val": 33},
    ]

    expected = {
        1: {"id": 1, "val": 11},
        2: {"id": 2, "val": 22},
        3: {"id": 3, "val": 33},
    }

    transformed = _transform_identification("id", input_data)
    assert transformed == expected


def test_identify_object_unmapped():
    input_data = [{"id": 1, "val": 11}]
    with pytest.raises(ValueError, match="Identifier cannot be empty."):
        _transform_identification("", input_data)


def test_transform_identification_missing_key():
    input_data = [{"id": 1, "val": 11}, {"val": 22}]
    with pytest.raises(
        KeyError,
        match="Item at index 1 is missing the required identifier 'id'",
    ):
        _transform_identification("id", input_data)


def test_diff_list():
    before_data = [
        {"key": "a", "val": 1},
        {"key": "b", "val": 2},
        {"key": "z", "val": 9},
    ]
    after_data = [
        {"key": "a", "val": 11},
        {"key": "c", "val": 3},
        {"key": "d", "val": 4},
        {"key": "z", "val": 9},
    ]

    result = diff(before_data, after_data, "key")

    assert sorted(result["added"], key=lambda x: x["key"]) == [
        {"key": "c", "val": 3},
        {"key": "d", "val": 4},
    ]
    assert result["deleted"] == [{"key": "b", "val": 2}]
    assert result["modified"] == [{"key": "a", "val": 11}]


def test_diff_dict():
    before_data = {
        "first": [{"key": "a", "val": 1}, {"key": "b", "val": 2}],
        "second": [{"key": "a", "val": 1}, {"key": "b", "val": 2}],
        "third": [{"key": "a", "val": 1}, {"key": "b", "val": 2}],
    }
    after_data = {
        "first": [{"key": "a", "val": 11}, {"key": "c", "val": 3}],
        "fourth": [{"key": "a", "val": 1}, {"key": "f", "val": 4}],
        "third": [{"key": "b", "val": 22}],
    }

    result = diff(before_data, after_data, "key")

    assert result["added"] == {
        "first": [{"key": "c", "val": 3}],
        "fourth": [{"key": "a", "val": 1}, {"key": "f", "val": 4}],
    }
    assert result["deleted"] == {
        "first": [{"key": "b", "val": 2}],
        "second": [{"key": "a", "val": 1}, {"key": "b", "val": 2}],
        "third": [{"key": "a", "val": 1}],
    }
    assert result["modified"] == {
        "first": [{"key": "a", "val": 11}],
        "third": [{"key": "b", "val": 22}],
    }


def test_diff_invalid_types():
    with pytest.raises(TypeError, match="Invalid contents to diff."):
        diff([1], {"a": 1}, "id")


def test_diff_list_no_identifier():
    with pytest.raises(
        ValueError, match="Identifier is needed to diff lists."
    ):
        diff([], [], "")


def test_transform_identification_no_identifier():
    with pytest.raises(ValueError, match="Identifier cannot be empty."):
        _transform_identification("", [])


def test_diff_dict_nested_dict():
    before_data = {"outer": {"inner_list": [{"key": "a", "val": 1}]}}
    after_data = {
        "outer": {
            "inner_list": [{"key": "a", "val": 2}, {"key": "b", "val": 3}]
        }
    }
    result = diff(before_data, after_data, "key")
    assert result["modified"] == {
        "outer": {"inner_list": [{"key": "a", "val": 2}]}
    }
    assert result["added"] == {
        "outer": {"inner_list": [{"key": "b", "val": 3}]}
    }
    assert result["deleted"] == {}


def test_diff_dict_primitive_values():
    before_data = {
        "primitive_modified": "old",
        "primitive_same": "same",
        "primitive_list_to_str": ["list"],
    }
    after_data = {
        "primitive_modified": "new",
        "primitive_same": "same",
        "primitive_list_to_str": "str",
    }
    result = diff(before_data, after_data, "key")
    assert result["modified"]["primitive_modified"] == "new"
    assert "primitive_same" not in result["modified"]
    assert result["modified"]["primitive_list_to_str"] == "str"


def test_diff_dict_mixed_types():
    # Test list replaced by dict
    before_data = {"key": [1, 2, 3]}
    after_data = {"key": {"a": 1}}
    result = diff(before_data, after_data, "id")
    assert result["modified"]["key"] == {"a": 1}
    assert result["added"] == {}
    assert result["deleted"] == {}

    # Test dict replaced by list
    before_data = {"key": {"a": 1}}
    after_data = {"key": [1, 2, 3]}
    result = diff(before_data, after_data, "id")
    assert result["modified"]["key"] == [1, 2, 3]


def test_transform_identification_type_error():
    # Test when item is not a dict
    input_data = ["not a dict"]
    with pytest.raises(
        KeyError,
        match="Item at index 0 is missing the required identifier 'id'",
    ):
        _transform_identification("id", input_data)


def test_diff_dict_nested_dict_deleted():
    before_data = {"outer": {"key1": "val1", "key2": "val2"}}
    after_data = {"outer": {"key1": "val1"}}
    result = diff(before_data, after_data, "id")
    assert result["deleted"] == {"outer": {"key2": "val2"}}

    assert result["added"] == {}
    assert result["modified"] == {}


def test_diff_dict_list_of_primitives():
    """Test that lists of primitives are handled correctly."""
    before_data = {"env": ["test", "prod"], "other": ["same"]}
    after_data = {"env": ["test", "dev"], "other": ["same"]}
    result = diff(before_data, after_data, "name")
    assert result["modified"] == {"env": ["test", "dev"]}
    assert result["added"] == {}
    assert result["deleted"] == {}
