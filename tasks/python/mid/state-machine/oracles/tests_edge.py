from fsm import StateMachine, TransitionError

rules = [
    ("draft", "submit", "review"),
    ("review", "approve", "done"),
    ("*", "cancel", "cancelled"),
    ("done", "cancel", "done"),  # exact rule beats the wildcard
]
m = StateMachine("draft", rules)

# wildcard applies from any state
assert m.can("cancel") is True
assert m.trigger("cancel") == "cancelled"
# history records the actual source state, not "*"
assert m.history == [("draft", "cancel", "cancelled")]

# exact rule wins over the wildcard
m.reset()
assert m.state == "draft"
assert m.history == []
m.trigger("submit")
m.trigger("approve")
assert m.state == "done"
assert m.trigger("cancel") == "done"  # exact ("done","cancel") -> stays done
assert m.history[-1] == ("done", "cancel", "done")

# events(): exact + wildcard, sorted, deduplicated
m2 = StateMachine(
    "a",
    [
        ("a", "go", "b"),
        ("a", "stop", "a"),
        ("*", "reset", "a"),
        ("*", "go", "z"),  # shadowed from "a" by the exact rule, still just "go"
    ],
)
assert m2.events() == ["go", "reset", "stop"]
# from "b" the wildcard "go" applies
m2.trigger("go")
assert m2.state == "b"
assert m2.events() == ["go", "reset"]
assert m2.trigger("go") == "z"  # wildcard target, exact only exists for "a"

# duplicate rules rejected
for dup in [
    [("a", "e", "b"), ("a", "e", "c")],
    [("*", "e", "b"), ("*", "e", "c")],
]:
    try:
        StateMachine("a", dup)
    except ValueError:
        pass
    else:
        raise AssertionError("duplicate (source, event) should raise ValueError")

# wildcard machine from a state with no exact rules at all
m3 = StateMachine("s0", [("*", "tick", "s0")])
assert m3.trigger("tick") == "s0"
assert m3.history == [("s0", "tick", "s0")]

# failed trigger leaves everything alone even mid-history
try:
    m3.trigger("boom")
except TransitionError:
    pass
assert m3.state == "s0"
assert len(m3.history) == 1

print("ok")
