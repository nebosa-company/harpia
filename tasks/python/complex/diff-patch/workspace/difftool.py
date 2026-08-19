"""Unified diff / patch tools. See the project brief for the contract."""


class PatchError(Exception):
    pass


def diff(a, b):
    raise NotImplementedError


def apply_patch(text, patch):
    raise NotImplementedError


def revert(text, patch):
    raise NotImplementedError
