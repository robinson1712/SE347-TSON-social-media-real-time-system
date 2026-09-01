import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/chat.dart';
import '../../shared/widgets/presence_avatar.dart';
import '../../shared/widgets/user_inline.dart';
import '../auth/auth_provider.dart';
import 'chat_provider.dart';

const double _kWindowWidth = 300;
const double _kWindowHeight = 380;
const double _kHeaderHeight = 44;
const double _kGap = 10;

/// Facebook-desktop-style floating chat windows docked to the bottom-right
/// of the viewport, stacking leftward in the order they were opened (newest
/// closest to the corner). Rendered once at the AppShell level so windows
/// persist across page navigation, same as real Messenger chat heads.
class FloatingChatWindows extends ConsumerWidget {
  const FloatingChatWindows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = ref.watch(chatProvider.select((s) => s.openWindows));
    if (windows.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        for (var i = 0; i < windows.length; i++)
          Positioned(
            right: 16 + (windows.length - 1 - i) * (_kWindowWidth + _kGap),
            bottom: 0,
            child: _FloatingChatWindow(key: ValueKey(windows[i]), conversationId: windows[i]),
          ),
      ],
    );
  }
}

class _FloatingChatWindow extends ConsumerStatefulWidget {
  final String conversationId;

  const _FloatingChatWindow({super.key, required this.conversationId});

  @override
  ConsumerState<_FloatingChatWindow> createState() => _FloatingChatWindowState();
}

class _FloatingChatWindowState extends ConsumerState<_FloatingChatWindow> {
  final _controller = TextEditingController();

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(chatProvider.notifier).sendMessage(widget.conversationId, text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final myId = ref.watch(currentAccountIdProvider);
    final minimized = state.minimizedWindows.contains(widget.conversationId);

    Conversation? conversation;
    for (final c in state.conversations) {
      if (c.id == widget.conversationId) conversation = c;
    }
    final otherId = conversation != null && myId != null
        ? conversation.otherParticipant(myId)
        : null;
    final messages = state.messagesByConversation[widget.conversationId] ?? const [];

    return Material(
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Container(
        width: _kWindowWidth,
        height: minimized ? _kHeaderHeight : _kWindowHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Column(
          children: [
            _buildHeader(context, otherId),
            if (!minimized) ...[
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final mine = m.senderId == myId;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        constraints: const BoxConstraints(maxWidth: 220),
                        decoration: BoxDecoration(
                          color: mine ? Theme.of(context).primaryColor : const Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          m.deleted ? '(tin nhắn đã xoá)' : (m.content ?? ''),
                          style: TextStyle(
                            fontSize: 13,
                            color: mine ? Colors.white : Colors.black87,
                            fontStyle: m.deleted ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Aa',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border:
                              OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, size: 18),
                      onPressed: _send,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String? otherId) {
    return InkWell(
      onTap: () => ref.read(chatProvider.notifier).toggleMinimizeWindow(widget.conversationId),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: SizedBox(
        height: _kHeaderHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              if (otherId != null) ...[
                PresenceAvatar(userId: otherId, radius: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: UserNameText(
                    userId: otherId,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ] else
                const Expanded(
                  child: Text('Nhóm chat',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Thu nhỏ',
                onPressed: () =>
                    ref.read(chatProvider.notifier).toggleMinimizeWindow(widget.conversationId),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Đóng',
                onPressed: () =>
                    ref.read(chatProvider.notifier).closeFloatingWindow(widget.conversationId),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
