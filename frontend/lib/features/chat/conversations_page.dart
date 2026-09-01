import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/widgets/presence_avatar.dart';
import '../../shared/widgets/user_inline.dart';
import '../auth/auth_provider.dart';
import 'chat_provider.dart';

class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatProvider);
    final myId = ref.watch(currentAccountIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trò chuyện')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: state.loadingConversations
              ? const Center(child: CircularProgressIndicator())
              : state.conversations.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Chưa có cuộc trò chuyện nào',
                          style: TextStyle(color: Colors.grey.shade600)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.conversations.length,
                      itemBuilder: (context, index) {
                        final c = state.conversations[index];
                        final otherId = myId == null ? '' : c.otherParticipant(myId);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: otherId.isEmpty
                                ? const CircleAvatar(child: Icon(Icons.chat))
                                : PresenceAvatar(userId: otherId, radius: 22),
                            title: otherId.isEmpty
                                ? const Text('Nhóm chat')
                                : UserNameText(userId: otherId),
                            subtitle: Text(
                              c.lastMessagePreview ?? '(chưa có tin nhắn)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: (state.unreadByConversation[c.id] ?? 0) > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: (state.unreadByConversation[c.id] ?? 0) > 0
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                              ),
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (c.lastMessageAt != null)
                                  Text(DateFormat('HH:mm').format(c.lastMessageAt!),
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                if ((state.unreadByConversation[c.id] ?? 0) > 0) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: const BoxDecoration(
                                        color: Colors.red, shape: BoxShape.circle),
                                    child: Text('${state.unreadByConversation[c.id]}',
                                        style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () => context.push('/chat/${c.id}'),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
