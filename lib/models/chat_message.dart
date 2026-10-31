class ChatMessage {
  final int id;
  final int senderId;
  final String? senderName;
  final String body;
  final bool isRead;
  final String? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    this.senderName,
    required this.body,
    required this.isRead,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id:         j['id'] ?? 0,
    senderId:   j['sender_id'] ?? 0,
    senderName: j['sender_name'],
    body:       j['body'] ?? '',
    isRead:     j['is_read'] ?? false,
    createdAt:  j['created_at']?.toString(),
  );

  String get formattedTime {
    if (createdAt == null) return '';
    try {
      final d = DateTime.parse(createdAt!).toLocal();
      final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
      final m = d.minute.toString().padLeft(2, '0');
      final ampm = d.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ampm';
    } catch (_) { return ''; }
  }
}
