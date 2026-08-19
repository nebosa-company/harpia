/// Fixed-size isolate worker pool.

import 'dart:async';
import 'dart:isolate';

/// Error surfaced when a pooled task throws on its worker isolate.
class ComputeError implements Exception {
  final String message;

  ComputeError(this.message);

  @override
  String toString() => 'ComputeError: $message';
}

class _Job {
  final int id;
  final Function task;
  final Object? arg;

  _Job(this.id, this.task, this.arg);
}

class _Worker {
  final Isolate isolate;
  final SendPort port;
  bool busy = false;

  _Worker(this.isolate, this.port);
}

void _workerMain(SendPort ready) {
  final inbox = ReceivePort();
  ready.send(inbox.sendPort);
  inbox.listen((message) async {
    final data = message as List;
    final reply = data[0] as SendPort;
    final id = data[1] as int;
    final task = data[2] as Function;
    final arg = data[3];
    try {
      final dynamic result = await Future.sync(() => (task as dynamic)(arg));
      reply.send([id, true, result]);
    } catch (error) {
      reply.send([id, false, error.toString()]);
    }
  });
}

/// A pool of long-lived worker isolates executing submitted tasks.
class ComputePool {
  final List<_Worker> _workers;
  final ReceivePort _results = ReceivePort();
  final Map<int, Completer<Object?>> _pending = {};
  final Map<int, _Worker> _running = {};
  final List<_Job> _queue = [];
  int _nextId = 0;
  bool _closed = false;
  Completer<void>? _closeCompleter;

  ComputePool._(this._workers) {
    _results.listen(_onResult);
  }

  static Future<ComputePool> start(int size) {
    if (size < 1) throw ArgumentError('size must be >= 1');
    return _start(size);
  }

  static Future<ComputePool> _start(int size) async {
    final workers = <_Worker>[];
    for (var i = 0; i < size; i++) {
      final ready = ReceivePort();
      final isolate = await Isolate.spawn(_workerMain, ready.sendPort);
      final port = await ready.first as SendPort;
      workers.add(_Worker(isolate, port));
    }
    return ComputePool._(workers);
  }

  int get size => _workers.length;

  Future<R> run<Q, R>(FutureOr<R> Function(Q) task, Q arg) {
    if (_closed) throw StateError('pool is closed');
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _queue.add(_Job(id, task, arg));
    _dispatch();
    return completer.future.then((value) => value as R);
  }

  void _dispatch() {
    for (final worker in _workers) {
      if (_queue.isEmpty) break;
      if (worker.busy) continue;
      final job = _queue.removeAt(0);
      worker.busy = true;
      _running[job.id] = worker;
      worker.port.send([_results.sendPort, job.id, job.task, job.arg]);
    }
  }

  void _onResult(Object? message) {
    final data = message as List;
    final id = data[0] as int;
    final ok = data[1] as bool;
    final worker = _running.remove(id);
    if (worker != null) worker.busy = false;
    final completer = _pending.remove(id);
    if (completer != null) {
      if (ok) {
        completer.complete(data[2]);
      } else {
        completer.completeError(ComputeError(data[2] as String));
      }
    }
    _dispatch();
    if (_closed && _pending.isEmpty) _shutdown();
  }

  Future<void> close() {
    final existing = _closeCompleter;
    if (existing != null) return existing.future;
    _closed = true;
    final completer = Completer<void>();
    _closeCompleter = completer;
    if (_pending.isEmpty) _shutdown();
    return completer.future;
  }

  void _shutdown() {
    for (final worker in _workers) {
      worker.isolate.kill(priority: Isolate.immediate);
    }
    _results.close();
    final completer = _closeCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }
}
