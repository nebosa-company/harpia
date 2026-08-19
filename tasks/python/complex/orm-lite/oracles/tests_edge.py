import sqlite3

from minorm import Database, FloatField, IntField, Model, TextField


class Doc(Model):
    title = TextField(nullable=False)
    score = FloatField()
    views = IntField()


db = Database(":memory:")
db.create_table(Doc)
# create_table is idempotent
db.create_table(Doc)

# unknown constructor kwarg
try:
    Doc(title="x", bogus=1)
except TypeError:
    pass
else:
    raise AssertionError("unknown kwarg should raise TypeError")

# id may not be passed as a field and starts as None
d = Doc(title="t")
assert d.id is None

# hostile strings are stored verbatim (parameterized SQL)
evil = "Robert'); DROP TABLE doc;--"
row = db.insert(Doc(title=evil, score=0.5, views=7))
back = db.get(Doc, row.id)
assert back.title == evil
assert back.score == 0.5
assert back.views == 7
# table survived and still counts
assert db.count(Doc) == 1
names = [r[0] for r in db.conn.execute(
    "SELECT name FROM sqlite_master WHERE type='table'"
)]
assert "doc" in names

# float round-trip
db.insert(Doc(title="pi", score=3.25))
assert db.get(Doc, 2).score == 3.25

# filter validation
try:
    db.filter(Doc, nonexistent=1)
except ValueError:
    pass
else:
    raise AssertionError("filter on unknown field should raise ValueError")

# filter on id is allowed
assert [x.title for x in db.filter(Doc, id=2)] == ["pi"]

# NOT NULL enforced by the database
try:
    db.insert(Doc(title=None))
except sqlite3.IntegrityError:
    pass
else:
    raise AssertionError("NOT NULL violation should raise IntegrityError")

# update/delete require an id
loose = Doc(title="floating")
for op in (db.update, db.delete):
    try:
        op(loose)
    except ValueError:
        pass
    else:
        raise AssertionError("update/delete without id should raise ValueError")

# update writes every field
row2 = db.get(Doc, 2)
row2.title = "tau"
row2.score = 6.5
row2.views = 1
db.update(row2)
again = db.get(Doc, 2)
assert (again.title, again.score, again.views) == ("tau", 6.5, 1)

print("ok")
