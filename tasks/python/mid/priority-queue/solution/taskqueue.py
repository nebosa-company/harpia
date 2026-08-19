"""Priority task queue."""

import heapq
import itertools


class TaskQueue:
    def __init__(self):
        self._heap = []  # (-priority, seq, name, entry); entry = [alive]
        self._count = itertools.count()
        self._alive = 0

    def add(self, name, priority=0):
        entry = [True]
        heapq.heappush(self._heap, (-priority, next(self._count), name, entry))
        self._alive += 1

    def _prune(self):
        while self._heap and not self._heap[0][3][0]:
            heapq.heappop(self._heap)

    def peek(self):
        self._prune()
        if not self._heap:
            raise IndexError("peek from an empty queue")
        return self._heap[0][2]

    def pop(self):
        self._prune()
        if not self._heap:
            raise IndexError("pop from an empty queue")
        _, _, name, entry = heapq.heappop(self._heap)
        entry[0] = False
        self._alive -= 1
        return name

    def cancel(self, name):
        live = [item for item in self._heap if item[3][0] and item[2] == name]
        if not live:
            return False
        live.sort()  # heap tuple order == pop order
        live[0][3][0] = False
        self._alive -= 1
        return True

    def pop_all(self):
        out = []
        while len(self) > 0:
            out.append(self.pop())
        return out

    def clear(self):
        self._heap = []
        self._alive = 0

    def __len__(self):
        return self._alive
