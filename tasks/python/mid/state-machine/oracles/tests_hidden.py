from fsm import StateMachine, TransitionError

# a turnstile
turnstile = StateMachine(
    "locked",
    [
        ("locked", "coin", "unlocked"),
        ("unlocked", "push", "locked"),
        ("locked", "push", "locked"),
    ],
)
assert turnstile.state == "locked"
assert turnstile.can("coin") is True
assert turnstile.can("undefined") is False

assert turnstile.trigger("coin") == "unlocked"
assert turnstile.state == "unlocked"
assert turnstile.trigger("push") == "locked"
assert turnstile.trigger("push") == "locked"  # self-transition
assert turnstile.history == [
    ("locked", "coin", "unlocked"),
    ("unlocked", "push", "locked"),
    ("locked", "push", "locked"),
]

# invalid event: TransitionError, state and history untouched
try:
    turnstile.trigger("kick")
except TransitionError as e:
    msg = str(e)
    assert "locked" in msg and "kick" in msg, msg
else:
    raise AssertionError("invalid event should raise TransitionError")
assert turnstile.state == "locked"
assert len(turnstile.history) == 3

# a longer walk
doc = StateMachine(
    "draft",
    [
        ("draft", "submit", "review"),
        ("review", "approve", "published"),
        ("review", "reject", "draft"),
    ],
)
assert doc.trigger("submit") == "review"
assert doc.trigger("reject") == "draft"
assert doc.trigger("submit") == "review"
assert doc.trigger("approve") == "published"
assert doc.can("submit") is False
assert doc.state == "published"

print("ok")
