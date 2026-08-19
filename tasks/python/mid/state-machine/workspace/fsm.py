"""Declarative finite state machine. See the project brief for the contract."""


class TransitionError(Exception):
    pass


class StateMachine:
    def __init__(self, initial, transitions):
        raise NotImplementedError
