import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/api.dart';
import '../../models/conversation.dart';
import '../../widgets/taptap_navbar.dart';
import '../../widgets/empty_state.dart';

class BuyerMessagesScreen extends StatefulWidget {
  const BuyerMessagesScreen({super.key});
  @override State<BuyerMessagesScreen> createState() => _BuyerMessagesState();
}

class _BuyerMessagesState extends State<BuyerMessagesScreen> {
  List<Conversation> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ChatService.conversations();
      if (mounted) setState(() { _conversations = data; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to load messages.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: const TaptapNavBar(title: 'Messages', showBack: false),
      body: _loading
          ? const LoadingCenter()
          : _error != null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : _conversations.isEmpty
                  ? const EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'No messages yet',
                      subtitle: 'Start a conversation by messaging a seller from a product page',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: C.b600,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _conversations.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 76, color: C.border),
                        itemBuilder: (_, i) =>
                            _ConversationTile(
                              conv: _conversations[i],
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ChatThreadScreen(
                                    conversationId: _conversations[i].id,
                                    otherPartyName: _conversations[i].otherPartyName,
                                    productName: _conversations[i].product?.name,
                                  ),
                                ));
                                // Refresh unread counts when returning
                                _load();
                              },
                            ),
                      ),
                    ),
    );
  }
}

// ── Conversation list tile ─────────────────────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  final Conversation conv;
  final VoidCallback onTap;

  const _ConversationTile({required this.conv, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = conv.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          // ── Avatar with initials ─────────────────────────────────────
          Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: C.b100,
                child: Text(
                  _initials(conv.otherPartyName),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: C.b700),
                ),
              ),
              // Unread dot
              if (hasUnread)
                Positioned(
                  right: 0, top: 0,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: C.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // ── Name + preview ───────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        conv.otherPartyName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: hasUnread
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: C.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      conv.formattedTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: hasUnread ? C.b600 : C.textMuted,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Product context badge
                if (conv.product != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: C.b50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      conv.product!.name,
                      style: const TextStyle(
                          fontSize: 10, color: C.b700,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conv.lastMessagePreview,
                        style: TextStyle(
                          fontSize: 13,
                          color: hasUnread
                              ? C.textPrimary
                              : C.textSecondary,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasUnread)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: C.primaryGrad,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${conv.unreadCount}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT THREAD SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class ChatThreadScreen extends StatefulWidget {
  final int conversationId;
  final String otherPartyName;
  final String? productName;

  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    required this.otherPartyName,
    this.productName,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadState();
}

class _ChatThreadState extends State<ChatThreadScreen> {
  final _msgCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<_ChatMsg> _messages = [];
  bool _loading  = true;
  bool _sending  = false;
  String? _error;
  int? _myId; // current user's id — set from first message

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final conv = await ChatService.thread(widget.conversationId);
      if (mounted) {
        setState(() {
          _messages = conv.messages
              .map((m) => _ChatMsg(
                    id: m.id,
                    senderId: m.senderId,
                    senderName: m.senderName ?? '',
                    body: m.body,
                    time: m.formattedTime,
                  ))
              .toList();
          _loading = false;
        });
        _scrollToBottom();
      }
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to load messages.'; _loading = false; });
    }
  }

  Future<void> _send() async {
    final body = _msgCtrl.text.trim();
    if (body.isEmpty || _sending) return;
    _msgCtrl.clear();
    setState(() => _sending = true);
    try {
      final msg = await ChatService.send(widget.conversationId, body);
      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg(
            id: msg.id,
            senderId: msg.senderId,
            senderName: msg.senderName ?? '',
            body: msg.body,
            time: msg.formattedTime,
            isMine: true,
          ));
        });
        _scrollToBottom();
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: C.danger));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send. Try again.'),
              backgroundColor: C.danger));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: C.navbarGrad)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherPartyName,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            if (widget.productName != null)
              Text(widget.productName!,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const LoadingCenter()
          : _error != null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : Column(children: [
                  // ── Messages list ──────────────────────────────────
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final msg = _messages[i];
                        // First message sets the reference sender ID
                        _myId ??= msg.isMine == true ? msg.senderId : null;
                        final isMine = msg.isMine ??
                            (_myId != null && msg.senderId == _myId);
                        return _Bubble(msg: msg, isMine: isMine);
                      },
                    ),
                  ),

                  // ── Input bar ──────────────────────────────────────
                  Container(
                    padding: EdgeInsets.only(
                      left: 12, right: 8, top: 8,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: C.border)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: const TextStyle(
                                  color: C.textMuted, fontSize: 13),
                              filled: true,
                              fillColor: C.bg,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Send button
                        GestureDetector(
                          onTap: _send,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 42, height: 42,
                            decoration: const BoxDecoration(
                              gradient: C.primaryGrad,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Color(0x300E2A38),
                                    blurRadius: 8,
                                    offset: Offset(0, 3))
                              ],
                            ),
                            child: _sending
                                ? const Center(
                                    child: SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    ))
                                : const Icon(Icons.send_rounded,
                                    color: Colors.white, size: 18),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),
    );
  }
}

// ── Chat bubble ────────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final _ChatMsg msg;
  final bool isMine;

  const _Bubble({required this.msg, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other party avatar
          if (!isMine)
            CircleAvatar(
              radius: 14,
              backgroundColor: C.b100,
              child: Text(
                msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: C.b700),
              ),
            ),
          if (!isMine) const SizedBox(width: 6),

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(msg.senderName,
                        style: const TextStyle(
                            fontSize: 11, color: C.textMuted,
                            fontWeight: FontWeight.w600)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMine ? C.primaryGrad : null,
                    color: isMine ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 4,
                          offset: Offset(0, 2))
                    ],
                    border: isMine
                        ? null
                        : Border.all(color: C.border),
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  child: Text(msg.body,
                      style: TextStyle(
                          fontSize: 14,
                          color: isMine ? Colors.white : C.textPrimary,
                          height: 1.4)),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(msg.time,
                      style: const TextStyle(
                          fontSize: 10, color: C.textMuted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Internal message data class ────────────────────────────────────────────────
class _ChatMsg {
  final int id;
  final int senderId;
  final String senderName;
  final String body;
  final String time;
  final bool? isMine; // null = unknown until first render

  const _ChatMsg({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.time,
    this.isMine,
  });
}
