/// Team lookups and report formatting.
///
/// The record store is injected so the service can be used with any data.

import 'dart:async';

class TeamService {
  final Map<String, Map<String, Object?>> _users;
  final Map<String, Map<String, Object?>> _teams;

  TeamService(Map<String, Map<String, Object?>> users,
      Map<String, Map<String, Object?>> teams)
      : _users = users,
        _teams = teams;

  void loadUser(String id,
      void Function(Object? error, Map<String, Object?>? user) callback) {
    scheduleMicrotask(() {
      final user = _users[id];
      if (user == null) {
        callback(StateError('no user: $id'), null);
      } else {
        callback(null, user);
      }
    });
  }

  void loadTeam(String id,
      void Function(Object? error, Map<String, Object?>? team) callback) {
    scheduleMicrotask(() {
      final team = _teams[id];
      if (team == null) {
        callback(StateError('no team: $id'), null);
      } else {
        callback(null, team);
      }
    });
  }

  Future<String> teamReport(String teamId) {
    final completer = Completer<String>();
    loadTeam(teamId, (error, team) {
      if (error != null) {
        completer.completeError(error);
        return;
      }
      final memberIds = (team!['members'] as List).cast<String>();
      final lines = <String>[];
      void loadNext(int index) {
        if (index == memberIds.length) {
          completer.complete('${team['name']}:\n${lines.join('\n')}');
          return;
        }
        loadUser(memberIds[index], (error, user) {
          if (error != null) {
            completer.completeError(error);
            return;
          }
          lines.add('- ${user!['name']} (${user['role']})');
          loadNext(index + 1);
        });
      }

      loadNext(0);
    });
    return completer.future;
  }
}
