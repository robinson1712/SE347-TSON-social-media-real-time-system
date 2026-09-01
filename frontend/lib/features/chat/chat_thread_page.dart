import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/chat.dart';
import '../../shared/widgets/user_inline.dart';
import '../auth/auth_provider.dart';
import '../profile/user_lookup_provider.dart';
import 'chat_provider.dart';

class ChatThreadPage extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatThreadPage({super.key, required this.conversationId});

  @override
  ConsumerState<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _StoryReplyPreview extends StatelessWidget {
  final String? previewUrl;
  final bool mine;

  const _StoryReplyPreview({required this.previewUrl, required this.mine});

  @override
  Widget build(BuildContext context) {
    final labelColor = mine ? Colors.white70 : Colors.grey.shade600;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (previewUrl != null && previewUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(previewUrl!, width: 36, height: 48, fit: BoxFit.cover),
            ),
          const SizedBox(width: 6),
          Text(mine ? 'Bạn đã trả lời story' : 'Đã trả lời story của bạn',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: labelColor)),
        ],
      ),
    );
  }
}

class _ChatThreadPageState extends ConsumerState<ChatThreadPage> {
  final _controller = TextEditingController();
  Timer? _refreshTimer;

  // Captured once while `ref` is guaranteed valid, then used directly
  // everywhere else (including dispose()) instead of calling `ref.read`
  // again later. Riverpod's ConsumerStatefulElement invalidates `ref`
  // before State.dispose() runs, so `ref.read(...)` inside dispose() (or in
  // any callback that can fire after unmount, like a Timer or microtask)
  // throws "Cannot use 'ref' after the widget was disposed".
  late final ChatNotifier _chatNotifier;

  @override
  void initState() {
    super.initState();
    _chatNotifier = ref.read(chatProvider.notifier);
    Future.microtask(() {
      if (!mounted) return;
      _chatNotifier.openConversation(widget.conversationId);
      _chatNotifier.loadMessages(widget.conversationId);
      _chatNotifier.markRead(widget.conversationId);
    });
    // The backend has no push event for "message was read" — poll gently
    // while this thread is open so the "Đã xem" indicator isn't stuck on
    // whatever was true at the moment the page opened. Guarded with
    // `mounted` since Timer.cancel() in dispose() can't retroactively stop
    // a callback that was already dispatched in the same event-loop tick.
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      _chatNotifier.loadMessages(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _chatNotifier.closeConversation(widget.conversationId);
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _chatNotifier.sendMessage(widget.conversationId, text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final myId = ref.watch(currentAccountIdProvider);
    final messages = state.messagesByConversation[widget.conversationId] ?? const [];
    final loading = state.loadingMessagesFor.contains(widget.conversationId);

    Conversation? conversation;
    for (final c in state.conversations) {
      if (c.id == widget.conversationId) conversation = c;
    }
    final otherId = conversation != null && myId != null
        ? conversation.otherParticipant(myId)
        : null;

    final myReceipts = myId == null ? true : ref.watch(userLookupProvider(myId)).value?.readReceiptsEnabled ?? true;
    final otherReceipts =
        otherId == null ? true : ref.watch(userLookupProvider(otherId)).value?.readReceiptsEnabled ?? true;
    final receiptsVisible = myReceipts && otherReceipts;
    final lastMineIndex = receiptsVisible && otherId != null
        ? messages.indexWhere((m) => m.senderId == myId)
        : -1;
    final lastMineSeen = lastMineIndex >= 0 && messages[lastMineIndex].readBy.contains(otherId);

    return Scaffold(
      appBar: AppBar(
        title: otherId == null ? const Text('Trò chuyện') : UserNameText(userId: otherId),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Expanded(
                child: loading && messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final m = messages[index];
                          final mine = m.senderId == myId;
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              constraints: const BoxConstraints(maxWidth: 420),
                              decoration: BoxDecoration(
                                color: mine
                                    ? Theme.of(context).primaryColor
                                    : const Color(0xFFF0F2F5),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!m.deleted && m.storyReplyId != null)
                                    _StoryReplyPreview(
                                      previewUrl: m.storyReplyPreviewUrl,
                                      mine: mine,
                                    ),
                                  Text(
                                    m.deleted ? '(tin nhắn đã xoá)' : (m.content ?? ''),
                                    style: TextStyle(
                                      color: mine ? Colors.white : Colors.black87,
                                      fontStyle: m.deleted ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                                  if (m.sentAt != null)
                                    Text(
                                      DateFormat('HH:mm').format(m.sentAt!),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: mine ? Colors.white70 : Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (lastMineSeen)
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('Đã xem',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(hintText: 'Nhắn tin...'),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.send), onPressed: _send),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
