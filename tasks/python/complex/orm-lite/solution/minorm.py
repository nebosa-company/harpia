"""Miniature ORM over sqlite3."""

import sqlite3


class Field:
    sql_type = "TEXT"

    def __init__(self, nullable=True):
        self.nullable = nullable


class IntField(Field):
    sql_type = "INTEGER"


class TextField(Field):
    sql_type = "TEXT"


class FloatField(Field):
    sql_type = "REAL"


class Model:
    def __init_subclass__(cls, **kwargs):
        super().__init_subclass__(**kwargs)
        fields = {}
        for base in reversed(cls.__mro__):
            for name, value in vars(base).items():
                if isinstance(value, Field):
                    fields[name] = value
        cls._fields = fields

    def __init__(self, **kwargs):
        cls = type(self)
        self.id = None
        for name in cls._fields:
            setattr(self, name, None)
        for name, value in kwargs.items():
            if name not in cls._fields:
                raise TypeError(
                    f"{cls.__name__} has no field {name!r}"
                )
            setattr(self, name, value)

    @classmethod
    def table_name(cls):
        return cls.__name__.lower()

    @classmethod
    def model_fields(cls):
        return dict(cls._fields)


class Database:
    def __init__(self, path=":memory:"):
        self.conn = sqlite3.connect(path)

    def create_table(self, model_cls):
        cols = ["id INTEGER PRIMARY KEY AUTOINCREMENT"]
        for name, field in model_cls.model_fields().items():
            col = f"{name} {field.sql_type}"
            if not field.nullable:
                col += " NOT NULL"
            cols.append(col)
        sql = (
            f"CREATE TABLE IF NOT EXISTS {model_cls.table_name()} "
            f"({', '.join(cols)})"
        )
        self.conn.execute(sql)
        self.conn.commit()

    def insert(self, obj):
        cls = type(obj)
        names = list(cls.model_fields())
        placeholders = ", ".join("?" for _ in names)
        sql = (
            f"INSERT INTO {cls.table_name()} ({', '.join(names)}) "
            f"VALUES ({placeholders})"
        )
        cur = self.conn.execute(sql, [getattr(obj, n) for n in names])
        self.conn.commit()
        obj.id = cur.lastrowid
        return obj

    def _hydrate(self, model_cls, row):
        names = list(model_cls.model_fields())
        obj = model_cls(**dict(zip(names, row[1:])))
        obj.id = row[0]
        return obj

    def _select(self, model_cls, where="", params=()):
        names = list(model_cls.model_fields())
        cols = ", ".join(["id"] + names)
        sql = f"SELECT {cols} FROM {model_cls.table_name()}"
        if where:
            sql += f" WHERE {where}"
        sql += " ORDER BY id ASC"
        rows = self.conn.execute(sql, params).fetchall()
        return [self._hydrate(model_cls, r) for r in rows]

    def get(self, model_cls, id):
        found = self._select(model_cls, "id = ?", (id,))
        return found[0] if found else None

    def all(self, model_cls):
        return self._select(model_cls)

    def filter(self, model_cls, **field_values):
        allowed = set(model_cls.model_fields()) | {"id"}
        for name in field_values:
            if name not in allowed:
                raise ValueError(f"unknown field {name!r}")
        if not field_values:
            return self.all(model_cls)
        clauses = " AND ".join(f"{name} = ?" for name in field_values)
        return self._select(model_cls, clauses, tuple(field_values.values()))

    def update(self, obj):
        if obj.id is None:
            raise ValueError("cannot update an object without an id")
        cls = type(obj)
        names = list(cls.model_fields())
        sets = ", ".join(f"{n} = ?" for n in names)
        sql = f"UPDATE {cls.table_name()} SET {sets} WHERE id = ?"
        self.conn.execute(sql, [getattr(obj, n) for n in names] + [obj.id])
        self.conn.commit()

    def delete(self, obj):
        if obj.id is None:
            raise ValueError("cannot delete an object without an id")
        cls = type(obj)
        self.conn.execute(
            f"DELETE FROM {cls.table_name()} WHERE id = ?", (obj.id,)
        )
        self.conn.commit()
        obj.id = None

    def count(self, model_cls):
        row = self.conn.execute(
            f"SELECT COUNT(*) FROM {model_cls.table_name()}"
        ).fetchone()
        return row[0]
