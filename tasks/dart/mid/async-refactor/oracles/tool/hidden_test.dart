import 'dart:io';

import '../lib/team_service.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected <$expected>, got <$actual>');
    failures++;
  }
}

TeamService build() => TeamService({
      'u1': {'name': 'Ada', 'role': 'engineer'},
      'u2': {'name': 'Grace', 'role': 'admiral'},
      'u3': {'name': 'Edsger', 'role': 'theorist'},
    }, {
      't1': {
        'name': 'Compilers',
        'members': ['u1', 'u2'],
      },
      't2': {
        'name': 'Solo',
        'members': ['u3'],
      },
      't3': {
        'name': 'Empty',
        'members': <String>[],
      },
      'broken': {
        'name': 'Broken',
        'members': ['u1', 'ghost'],
      },
    });

Future<void> main() async {
  final service = build();

  // The new API shape: lookups return Futures directly.
  final Future<Map<String, Object?>> userFuture = service.loadUser('u1');
  final user = await userFuture;
  check('loadUser value', user['name'], 'Ada');

  final Future<Map<String, Object?>> teamFuture = service.loadTeam('t1');
  final team = await teamFuture;
  check('loadTeam value', team['name'], 'Compilers');

  // Behavior preserved.
  check('report', await service.teamReport('t1'),
      'Compilers:\n- Ada (engineer)\n- Grace (admiral)');
  check('single member', await service.teamReport('t2'),
      'Solo:\n- Edsger (theorist)');
  check('empty members', await service.teamReport('t3'), 'Empty:\n');

  // Error propagation.
  Object? unknownUser;
  try {
    await service.loadUser('nope');
  } catch (e) {
    unknownUser = e;
  }
  check('unknown user type', unknownUser is StateError, true);
  check('unknown user message', '$unknownUser', 'Bad state: no user: nope');

  Object? unknownTeam;
  try {
    await service.teamReport('ghost-team');
  } catch (e) {
    unknownTeam = e;
  }
  check('unknown team type', unknownTeam is StateError, true);
  check('unknown team message', '$unknownTeam',
      'Bad state: no team: ghost-team');

  Object? brokenMember;
  try {
    await service.teamReport('broken');
  } catch (e) {
    brokenMember = e;
  }
  check('missing member type', brokenMember is StateError, true);
  check('missing member message', '$brokenMember', 'Bad state: no user: ghost');
  if (failures > 0) exit(1);
  print('core ok');
}
