"""Declarative finite state machine."""


class TransitionError(Exception):
    pass


class StateMachine:
    def __init__(self, initial, transitions):
        self._initial = initial
        self._rules = {}
        for source, event, target in transitions:
            key = (source, event)
            if key in self._rules:
                raise ValueError(f"duplicate rule for {key!r}")
            self._rules[key] = target
        self.state = initial
        self.history = []

    def _target(self, event):
        exact = self._rules.get((self.state, event))
        if exact is not None:
            return exact
        return self._rules.get(("*", event))

    def can(self, event):
        return self._target(event) is not None

    def trigger(self, event):
        target = self._target(event)
        if target is None:
            raise TransitionError(
                f"no transition from state {self.state!r} on event {event!r}"
            )
        self.history.append((self.state, event, target))
        self.state = target
        return target

    def events(self):
        names = {
            event
            for (source, event) in self._rules
            if source == self.state or source == "*"
        }
        return sorted(names)

    def reset(self):
        self.state = self._initial
        self.history = []
