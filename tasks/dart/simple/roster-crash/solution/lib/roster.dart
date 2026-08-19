/// Team roster formatting.

class Member {
  final String name;
  final String? nickname;
  final String? email;

  Member(this.name, {this.nickname, this.email});
}

/// One line for [member]: display part, a space, then contact part.
String displayLine(Member member) {
  final nickname = member.nickname;
  final email = member.email;
  final display = nickname == null ? member.name : '$nickname (${member.name})';
  final contact = email == null ? '(no email)' : '<$email>';
  return '$display $contact';
}

/// All members, one line each, joined with newlines.
String rosterReport(List<Member> members) =>
    members.map(displayLine).join('\n');
