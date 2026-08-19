"""Miniature ORM over sqlite3. See the project brief for the contract."""


class IntField:
    def __init__(self, nullable=True):
        raise NotImplementedError


class TextField:
    def __init__(self, nullable=True):
        raise NotImplementedError


class FloatField:
    def __init__(self, nullable=True):
        raise NotImplementedError


class Model:
    pass


class Database:
    def __init__(self, path=":memory:"):
        raise NotImplementedError
