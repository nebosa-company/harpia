import '../lib/team_service.dart';

Future<void> main() async {
  final service = TeamService({
    'u1': {'name': 'Ada', 'role': 'engineer'},
    'u2': {'name': 'Grace', 'role': 'admiral'},
  }, {
    't1': {
      'name': 'Compilers',
      'members': ['u1', 'u2'],
    },
  });

  final report = await service.teamReport('t1');
  const expected = 'Compilers:\n- Ada (engineer)\n- Grace (admiral)';
  if (report != expected) {
    throw StateError('unexpected report:\n$report');
  }

  var threw = false;
  try {
    await service.teamReport('missing');
  } on StateError {
    threw = true;
  }
  if (!threw) throw StateError('expected StateError for unknown team');
  print('behavior check passed');
}
