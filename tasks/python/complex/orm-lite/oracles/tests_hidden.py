from minorm import Database, FloatField, IntField, Model, TextField


class User(Model):
    name = TextField(nullable=False)
    age = IntField()


class Note(Model):
    body = TextField()
    weight = FloatField()


assert User.table_name() == "user"
assert Note.table_name() == "note"
assert list(User.model_fields().keys()) == ["name", "age"]
assert list(Note.model_fields().keys()) == ["body", "weight"]

db = Database(":memory:")
db.create_table(User)
db.create_table(Note)

# schema: table exists with expected columns and types
cols = db.conn.execute("PRAGMA table_info(user)").fetchall()
info = {c[1]: (c[2].upper(), c[3]) for c in cols}  # name -> (type, notnull)
assert info["id"][0] == "INTEGER"
assert info["name"][0] == "TEXT"
assert info["name"][1] == 1, "name must be NOT NULL"
assert info["age"][0] == "INTEGER"
assert info["age"][1] == 0, "age must be nullable"

# insert assigns ids in order
u1 = db.insert(User(name="ada", age=36))
u2 = db.insert(User(name="bob", age=25))
u3 = db.insert(User(name="cid"))
assert u1.id == 1 and u2.id == 2 and u3.id == 3
assert db.count(User) == 3

# get
got = db.get(User, 2)
assert isinstance(got, User)
assert got.id == 2 and got.name == "bob" and got.age == 25
assert db.get(User, 99) is None

# omitted fields are None end to end
assert db.get(User, 3).age is None

# all(): ordered by id
names = [u.name for u in db.all(User)]
assert names == ["ada", "bob", "cid"]

# filter with one and several equalities
db.insert(User(name="ada", age=99))
adas = db.filter(User, name="ada")
assert [u.id for u in adas] == [1, 4]
assert [u.age for u in db.filter(User, name="ada", age=36)] == [36]
assert db.filter(User, name="nobody") == []

# update
u2.age = 26
db.update(u2)
assert db.get(User, 2).age == 26

# delete
db.delete(u3)
assert db.count(User) == 3
assert db.get(User, 3) is None
assert u3.id is None

# the two models are independent
db.insert(Note(body="hello", weight=1.5))
assert db.count(Note) == 1
assert db.count(User) == 3

print("ok")
