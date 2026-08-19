"""Small helpers for building item records.

Contract:

- ``new_item(name, tags)`` returns ``{"name": name, "tags": <list>}`` where
  the tag list is the caller-supplied tags (if any) followed by the
  automatic tag ``"item"``. Every record owns a fresh list; the caller's
  list is never modified.
- ``merge_tags(record, extra)`` appends each tag from ``extra`` that the
  record does not already carry, in order, and returns the record.
"""


def new_item(name, tags=None):
    tag_list = list(tags) if tags is not None else []
    tag_list.append("item")
    return {"name": name, "tags": tag_list}


def merge_tags(record, extra=()):
    for tag in extra:
        if tag not in record["tags"]:
            record["tags"].append(tag)
    return record
