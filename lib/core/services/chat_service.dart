import '../services/api.dart';
import '../../models/conversation.dart';
import '../../models/chat_message.dart';

class ChatService {
  // GET /api/chat — conversation list
  static Future<List<Conversation>> conversations() async {
    final d = await Api.get('/chat') as List;
    return d
        .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  // GET /api/chat/{id} — thread with messages (marks incoming as read)
  static Future<Conversation> thread(int conversationId) async {
    final d = await Api.get('/chat/$conversationId') as Map<String, dynamic>;
    return Conversation.fromJson(d);
  }

  // POST /api/chat/{id}/send — send a message
  static Future<ChatMessage> send(int conversationId, String body) async {
    final d = await Api.post('/chat/$conversationId/send',
        body: {'body': body}) as Map<String, dynamic>;
    return ChatMessage.fromJson(d);
  }

  // POST /api/chat/start/{sellerId} — start or open conversation
  static Future<Conversation> start({
    required int sellerId,
    int? productId,
  }) async {
    final d = await Api.post('/chat/start/$sellerId',
        body: {if (productId != null) 'product_id': productId})
        as Map<String, dynamic>;
    return Conversation.fromJson(d);
  }
}
