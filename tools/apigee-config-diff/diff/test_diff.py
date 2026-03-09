import pytest
from unittest.mock import patch
from .diff import _transform_identification, diff

def test_identify_object():

    input_data = [
        {"id": 1, "val": 11},
        {"id": 2, "val": 22},
        {"id": 3, "val": 33}
    ]

    expected = {
        1: {"id": 1, "val": 11},
        2: {"id": 2, "val": 22},
        3: {"id": 3, "val": 33}
    }

    transformed = _transform_identification("id", input_data)

    assert transformed == expected


def test_identify_object_unmapped():

    input_data = [
        {"id": 1, "val": 11},
        {"id": 2, "val": 22},
        {"id": 3, "val": 33}
    ]

    with pytest.raises(Exception):
        _transform_identification("", input_data)


def test_diff_list():

    before_data = [
        {
            "key": "a",
            "val": 1
        },
        {
            "key": "b",
            "val": 2
        },
        {
            "key": "z",
            "val": 9
        }
    ]

    after_data = [
        {
            "key": "a",
            "val": 11
        },
        {
            "key": "c",
            "val": 3
        },
        {
            "key": "d",
            "val": 4
        },
        {
            "key": "z",
            "val": 9
        }
    ]

    result = diff(before_data, after_data, "key")

    assert sorted(result["added"], key=lambda x:x["key"]) == [
        {"key": "c", "val": 3},
        {"key": "d", "val": 4}
    ]

    assert result["deleted"] == [
        {"key": "b", "val": 2}
    ]

    assert result["modified"] == [
        {"key": "a", "val": 11}
    ]


def test_diff_dict():

    before_data = {
        "first": [{
            "key": "a",
            "val": 1
        },{
            "key": "b",
            "val": 2
        }],

        "second": [{
            "key": "a",
            "val": 1
        },{
            "key": "b",
            "val": 2
        }],

        "third": [{
            "key": "a",
            "val": 1
        },{
            "key": "b",
            "val": 2
        }]
    }

    after_data = {
        "first": [{
            "key": "a",
            "val": 11
        },{
            "key": "c",
            "val": 3
        }],

        "fourth": [{
            "key": "a",
            "val": 1
        },{
            "key": "f",
            "val": 4
        }],

        "third": [{
            "key": "b",
            "val": 22
        }]
    }

    result = diff(before_data, after_data, "key")

    assert result["added"] == {
        "first": [{
            "key": "c",
            "val": 3
        }],
        "fourth": [{
            "key": "a",
            "val": 1
        }, {
            "key": "f",
            "val": 4
        }]
    }

    assert result["deleted"] == {
        "first": [{
            "key": "b",
            "val": 2
        }],
        "second": [{
            "key": "a",
            "val": 1
        }, {
            "key": "b",
            "val": 2
        }],
        "third": [{
            "key": "a",
            "val": 1
        }]
    }

    assert result["modified"] == {
        "first": [{
            "key": "a",
            "val": 11
        }],
        "third": [{
            "key": "b",
            "val": 22
        }]
    }
