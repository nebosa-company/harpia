import '../lib/roster.dart';

void main() {
  final members = [
    Member('Ada Lovelace', nickname: 'Ada', email: 'ada@example.com'),
    Member('Charles Babbage', email: 'cb@example.com'),
    Member('Grace Hopper', nickname: 'Amazing Grace'),
  ];
  print(rosterReport(members));
}
