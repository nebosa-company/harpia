/// Team lookups and report formatting.
///
/// The record store is injected so the service can be used with any data.

class TeamService {
  final Map<String, Map<String, Object?>> _users;
  final Map<String, Map<String, Object?>> _teams;

  TeamService(Map<String, Map<String, Object?>> users,
      Map<String, Map<String, Object?>> teams)
      : _users = users,
        _teams = teams;

  Future<Map<String, Object?>> loadUser(String id) async {
    final user = _users[id];
    if (user == null) throw StateError('no user: $id');
    return user;
  }

  Future<Map<String, Object?>> loadTeam(String id) async {
    final team = _teams[id];
    if (team == null) throw StateError('no team: $id');
    return team;
  }

  Future<String> teamReport(String teamId) async {
    final team = await loadTeam(teamId);
    final memberIds = (team['members'] as List).cast<String>();
    final lines = <String>[];
    for (final id in memberIds) {
      final user = await loadUser(id);
      lines.add('- ${user['name']} (${user['role']})');
    }
    return '${team['name']}:\n${lines.join('\n')}';
  }
}
