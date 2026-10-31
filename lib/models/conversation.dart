import 'chat_message.dart';

class ConversationParty {
  final int id;
  final String name;
  const ConversationParty({required this.id, required this.name});
  factory ConversationParty.fromJson(Map<String, dynamic> j) =>
      ConversationParty(id: j['id'] ?? 0, name: j['name'] ?? '');
}

class ConversationProduct {
  final int id;
  final String name;
  const ConversationProduct({required this.id, required this.name});
  factory ConversationProduct.fromJson(Map<String, dynamic> j) =>
      ConversationProduct(id: j['id'] ?? 0, name: j['name'] ?? '');
}

class LatestMessage {
  final String body;
  final int senderId;
  final bool isRead;
  final String? createdAt;
  const LatestMessage({
    required this.body, required this.senderId,
    required this.isRead, this.createdAt,
  });
  factory LatestMessage.fromJson(Map<String, dynamic> j) => LatestMessage(
    body:      j['body'] ?? '',
    senderId:  j['sender_id'] ?? 0,
    isRead:    j['is_read'] ?? false,
    createdAt: j['created_at']?.toString(),
  );
}

class Conversation {
  final int id;
  final ConversationParty? otherParty;
  final ConversationProduct? product;
  final LatestMessage? latestMessage;
  final int unreadCount;
  final String? lastMessageAt;
  final String status;
  // Full message list — only populated when opening a thread
  final List<ChatMessage> messages;

  const Conversation({
    required this.id,
    this.otherParty,
    this.product,
    this.latestMessage,
    this.unreadCount = 0,
    this.lastMessageAt,
    this.status = 'open',
    this.messages = const [],
  });

  bool get hasUnread => unreadCount > 0;

  String get otherPartyName => otherParty?.name ?? 'Unknown';

  String get lastMessagePreview =>
      latestMessage?.body.isNotEmpty == true
          ? latestMessage!.body
          : 'No messages yet';

  String get formattedTime {
    final ts = lastMessageAt ?? latestMessage?.createdAt;
    if (ts == null) return '';
    try {
      final d = DateTime.parse(ts).toLocal();
      final now = DateTime.now();
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
        final m = d.minute.toString().padLeft(2, '0');
        final ampm = d.hour >= 12 ? 'PM' : 'AM';
        return '$h:$m $ampm';
      }
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[d.month - 1]} ${d.day}';
    } catch (_) { return ''; }
  }

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    id:            j['id'] ?? 0,
    otherParty:    j['other_party'] != null
        ? ConversationParty.fromJson(j['other_party'] as Map<String, dynamic>)
        : null,
    product:       j['product'] != null
        ? ConversationProduct.fromJson(j['product'] as Map<String, dynamic>)
        : null,
    latestMessage: j['latest_message'] != null
        ? LatestMessage.fromJson(j['latest_message'] as Map<String, dynamic>)
        : null,
    unreadCount:   j['unread_count'] ?? 0,
    lastMessageAt: j['last_message_at']?.toString(),
    status:        j['status'] ?? 'open',
    messages: (j['messages'] as List<dynamic>?)
            ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList()
        ?? const [],
  );

  Conversation withMessages(List<ChatMessage> msgs) => Conversation(
    id: id, otherParty: otherParty, product: product,
    latestMessage: latestMessage, unreadCount: 0,
    lastMessageAt: lastMessageAt, status: status,
    messages: msgs,
  );
}
