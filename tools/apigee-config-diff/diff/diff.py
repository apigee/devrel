from typing import Union


def _transform_identification(identifier: str, content: list) -> dict:
    if not identifier:
        raise Exception(f"Identifier cannot be empty.")

    return {k[identifier]: k for k in content}


def _diff_keys(before_dict: dict, after_dict: dict) -> tuple[set, set, set]:
    return (
        # Added
        after_dict.keys() - before_dict.keys(),
        # Deleted
        before_dict.keys() - after_dict.keys(),
        # Same
        after_dict.keys() & before_dict.keys()
    )


def _diff_list(identifier: str, before_content: list, after_content: list) -> dict[str, list]:

    # Transform list to dict using identifier as key
    before_identified = _transform_identification(identifier, before_content)
    after_identified = _transform_identification(identifier, after_content)

    # Diff the keys
    added_keys, deleted_keys, same_keys = _diff_keys(before_identified, after_identified)

    return {
        "added": [after_identified[a] for a in added_keys],
        "deleted": [before_identified[d] for d in deleted_keys],
        "modified": [after_identified[k] for k in same_keys if after_identified[k] != before_identified[k]]
    }


def _diff_dict(identifier: str, before_content: dict, after_content: dict) -> dict[str, dict]:

    added_keys, deleted_keys, same_keys = _diff_keys(before_content, after_content)

    # Diff content
    added = {a: after_content[a] for a in added_keys}
    deleted = {d: before_content[d] for d in deleted_keys}
    modified = {}

    # Diff list inside each key
    for k in same_keys:
        d = _diff_list(identifier, before_content[k], after_content[k])
        added.update({k: d['added']} if d['added'] else {})
        deleted.update({k: d['deleted']} if d['deleted'] else {})
        modified.update({k: d['modified']} if d['modified'] else {})

    return {
        "added": added,
        "deleted": deleted,
        "modified": modified
    }


# TODO: Make it generic for nested in the future (only working for single level now)
def diff(before_content: Union[list, dict], after_content: Union[list, dict], identifier: str):

    # Handle dicts
    if isinstance(before_content, dict) and isinstance(after_content, dict):
        return _diff_dict(identifier, before_content, after_content)

    # Handle lists
    elif isinstance(before_content, list) and isinstance(after_content, list):

        if not identifier:
            raise Exception(f"identifier if needed to diff lists.")

        return _diff_list(identifier, before_content, after_content)

    raise Exception('Invalid contents to diff.')
