/// One message in a conversation.
class ChatMessage {
  const ChatMessage({
    required this.sender,
    required this.text,
    required this.sentAt,
    this.read = true,
  });

  final String sender;
  final String text;
  final DateTime sentAt;
  final bool read;
}
