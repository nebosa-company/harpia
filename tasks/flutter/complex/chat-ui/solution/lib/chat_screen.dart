import 'package:flutter/material.dart';

import 'chat_message.dart';

/// Renders a chronological transcript with day headers, sender runs,
/// timestamps, and a single unread divider.
class ChatScreen extends StatelessWidget {
  const ChatScreen({
    required this.messages,
    required this.currentUser,
    required this.now,
    super.key,
  });

  final List<ChatMessage> messages;
  final String currentUser;

  /// Reference time for 'Today' / 'Yesterday'. Never DateTime.now().
  final DateTime now;

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _isoDate(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}';

  static String _clock(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime day) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (_sameDay(day, today)) {
      return 'Today';
    }
    if (_sameDay(day, yesterday)) {
      return 'Yesterday';
    }
    return _isoDate(day);
  }

  int _firstUnreadIndex() {
    for (var i = 0; i < messages.length; i++) {
      if (!messages[i].read && messages[i].sender != currentUser) {
        return i;
      }
    }
    return -1;
  }

  bool _startsRun(int index) {
    if (index == 0) {
      return true;
    }
    final current = messages[index];
    final previous = messages[index - 1];
    if (previous.sender != current.sender) {
      return true;
    }
    if (!_sameDay(previous.sentAt, current.sentAt)) {
      return true;
    }
    return current.sentAt.difference(previous.sentAt) >=
        const Duration(minutes: 5);
  }

  @override
  Widget build(BuildContext context) {
    final unreadAt = _firstUnreadIndex();
    final children = <Widget>[];
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (i == 0 || !_sameDay(messages[i - 1].sentAt, message.sentAt)) {
        children.add(_dayHeader(context, message.sentAt));
      }
      if (i == unreadAt) {
        children.add(_unreadDivider(context));
      }
      children.add(_bubble(context, i));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: children,
    );
  }

  Widget _dayHeader(BuildContext context, DateTime day) {
    return Padding(
      key: Key('day-header-${_isoDate(day)}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          _dayLabel(day),
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }

  Widget _unreadDivider(BuildContext context) {
    return Padding(
      key: const Key('unread-divider'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Colors.red)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'New messages',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
          const Expanded(child: Divider(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, int index) {
    final message = messages[index];
    final own = message.sender == currentUser;
    final showLabel = !own && _startsRun(index);
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            own ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showLabel)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(
                message.sender,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          Container(
            key: Key('msg-$index'),
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: own ? Colors.indigo.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message.text),
                const SizedBox(height: 2),
                Text(
                  _clock(message.sentAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
