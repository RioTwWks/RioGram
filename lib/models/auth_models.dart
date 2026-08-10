enum AuthPhase {
  initializing,
  waitPhoneNumber,
  waitCode,
  waitPassword,
  ready,
  error,
}

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.title,
    this.lastMessage,
  });

  final int id;
  final String title;
  final String? lastMessage;
}
