"""Path handling that keeps every resolved location inside a root.

The functions here are string-level on purpose: they never touch the
filesystem, so they behave the same on every platform and in tests.
"""

_SEPARATORS = ("\\\\", "/")


class PathOutsideRoot(Exception):
    """Raised when a candidate path resolves outside its configured root."""


def normalise(path: str) -> str:
    """Return path with separators unified and redundant parts removed.

    Backslashes become forward slashes, repeated separators collapse, a
    trailing separator is dropped, and any `.` component disappears. A
    `..` component removes the segment before it.
    """
    parts = []
    for raw in path.replace("\\", "/").split("/"):
        if raw in ("", "."):
            continue
        if raw == ".." and parts:
            parts.pop()
        else:
            parts.append(raw)
    return "/".join(parts)


def is_within(root: str, candidate: str) -> bool:
    """Report whether candidate resolves to a location under root."""
    r, c = normalise(root), normalise(candidate)
    return c == r or c.startswith(r + "/")


class PathPolicy:
    """A root directory together with the file extensions it accepts."""

    def __init__(self, root: str, extensions: tuple) -> None:
        """Create a policy rooted at root accepting the given extensions."""
        self.root = normalise(root)
        self.extensions = tuple(e.lower() for e in extensions)

    def check(self, candidate: str) -> str:
        """Return the normalised candidate when the policy accepts it.

        Raises:
            PathOutsideRoot: if candidate resolves outside the root.
            ValueError: if the candidate carries an extension the policy
                does not accept.
        """
        resolved = normalise(candidate)
        if not is_within(self.root, resolved):
            raise PathOutsideRoot(resolved)
        suffix = resolved.rsplit(".", 1)[-1].lower() if "." in resolved else ""
        if suffix not in self.extensions:
            raise ValueError("extension not accepted: " + suffix)
        return resolved

    def describe(self) -> str:
        """Return a one-line human-readable summary of the policy."""
        return "%s (%s)" % (self.root, ", ".join(self.extensions))
