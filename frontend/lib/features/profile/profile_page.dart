import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/models/friendship.dart';
import '../../core/models/page_response.dart';
import '../../core/models/post.dart';
import '../../shared/widgets/avatar.dart';
import '../../shared/widgets/post_card.dart';
import '../auth/auth_provider.dart';
import '../chat/chat_provider.dart';
import '../posts/post_provider.dart';
import 'edit_profile_page.dart';
import 'profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  final String userId;

  const ProfilePage({super.key, required this.userId});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(currentAccountIdProvider);
    final isMe = myId == widget.userId;
    final profileAsync = ref.watch(viewedProfileProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Trang cá nhân')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: profileAsync.when(
            data: (profile) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (profile.coverUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(profile.coverUrl!,
                                height: 160, width: double.infinity, fit: BoxFit.cover),
                          ),
                        const SizedBox(height: 12),
                        Avatar(url: profile.avatarUrl, name: profile.fullName, radius: 44),
                        const SizedBox(height: 8),
                        Text(profile.fullName,
                            style: Theme.of(context).textTheme.headlineSmall),
                        if (profile.bio != null && profile.bio!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(profile.bio!),
                          ),
                        if (profile.location != null && profile.location!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('📍 ${profile.location}',
                                style: TextStyle(color: Colors.grey.shade600)),
                          ),
                        const SizedBox(height: 8),
                        _FollowCounts(targetId: widget.userId),
                        const SizedBox(height: 12),
                        if (isMe)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Chỉnh sửa trang cá nhân'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => EditProfilePage(profile: profile)),
                            ),
                          )
                        else
                          _FriendshipActionsRow(
                            myId: myId,
                            targetId: widget.userId,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Bài viết', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _UserPosts(userId: widget.userId),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Không tải được trang cá nhân: $e'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Facebook-style friend-request button, driven by [friendshipStatusProvider]:
/// NONE -> "Kết bạn"; PENDING_SENT -> "Đã gửi lời mời" (tap to cancel);
/// PENDING_RECEIVED -> Accept/Decline; FRIENDS -> "Bạn bè" (tap to unfriend).
class _FriendshipActionsRow extends ConsumerStatefulWidget {
  final String? myId;
  final String targetId;

  const _FriendshipActionsRow({required this.myId, required this.targetId});

  @override
  ConsumerState<_FriendshipActionsRow> createState() => _FriendshipActionsRowState();
}

class _FriendshipActionsRowState extends ConsumerState<_FriendshipActionsRow> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _runSafely(context, action);
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _confirm(String title, String content) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Huỷ')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận')),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.myId == null) return const SizedBox.shrink();
    final statusAsync = ref.watch(friendshipStatusProvider(widget.targetId));

    return statusAsync.when(
      data: (status) => Wrap(
        spacing: 8,
        children: [
          _buildFriendshipButton(status),
          _FollowButton(targetId: widget.targetId),
          OutlinedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Nhắn tin'),
            onPressed: () => _runSafely(context, () async {
              final conversation = await ref
                  .read(chatProvider.notifier)
                  .startConversationWith(widget.targetId);
              if (context.mounted) context.push('/chat/${conversation.id}');
            }),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.block),
            label: const Text('Chặn'),
            onPressed: () => _runSafely(context,
                () => ref.read(friendshipActionsProvider).block(widget.targetId)),
          ),
        ],
      ),
      loading: () => const SizedBox(
          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildFriendshipButton(FriendshipStatusModel status) {
    switch (status.status) {
      case RelationshipStatus.friends:
        return OutlinedButton.icon(
          icon: const Icon(Icons.people),
          label: const Text('Bạn bè'),
          onPressed: _busy
              ? null
              : () async {
                  final confirmed = await _confirm(
                    'Huỷ kết bạn?',
                    'Hai bạn sẽ không còn là bạn bè trên Social nữa.',
                  );
                  if (confirmed) {
                    await _run(() =>
                        ref.read(friendshipActionsProvider).removeFriend(widget.targetId));
                  }
                },
        );

      case RelationshipStatus.pendingSent:
        return OutlinedButton.icon(
          icon: const Icon(Icons.schedule_send),
          label: Text(_busy ? 'Đang xử lý...' : 'Đã gửi lời mời'),
          onPressed: _busy
              ? null
              : () async {
                  final confirmed = await _confirm(
                    'Huỷ lời mời kết bạn?',
                    'Lời mời kết bạn đã gửi sẽ bị huỷ.',
                  );
                  if (confirmed) {
                    await _run(() => ref
                        .read(friendshipActionsProvider)
                        .decline(status.friendshipId!));
                  }
                },
        );

      case RelationshipStatus.pendingReceived:
        return Wrap(
          spacing: 8,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Chấp nhận'),
              onPressed: _busy
                  ? null
                  : () => _run(() =>
                      ref.read(friendshipActionsProvider).accept(status.friendshipId!)),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('Từ chối'),
              onPressed: _busy
                  ? null
                  : () => _run(() =>
                      ref.read(friendshipActionsProvider).decline(status.friendshipId!)),
            ),
          ],
        );

      case RelationshipStatus.none:
        return ElevatedButton.icon(
          icon: const Icon(Icons.person_add),
          label: Text(_busy ? 'Đang gửi...' : 'Kết bạn'),
          onPressed: _busy
              ? null
              : () => _run(
                  () => ref.read(friendshipActionsProvider).sendRequest(widget.targetId)),
        );
    }
  }
}

class _FollowCounts extends ConsumerWidget {
  final String targetId;

  const _FollowCounts({required this.targetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(followStatusProvider(targetId));
    final status = statusAsync.value;
    if (status == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${status.followerCount}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text('người theo dõi', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(width: 16),
        Text('${status.followingCount}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text('đang theo dõi', style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }
}

/// Follow/Unfollow — independent of friendship: you can follow a stranger,
/// or unfollow a friend without unfriending them.
class _FollowButton extends ConsumerWidget {
  final String targetId;

  const _FollowButton({required this.targetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(followStatusProvider(targetId));
    final following = statusAsync.value?.following ?? false;

    return following
        ? OutlinedButton.icon(
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Bỏ theo dõi'),
            onPressed: () =>
                _runSafely(context, () => ref.read(followActionsProvider).unfollow(targetId)),
          )
        : ElevatedButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Theo dõi'),
            onPressed: () =>
                _runSafely(context, () => ref.read(followActionsProvider).follow(targetId)),
          );
  }
}

class _UserPosts extends ConsumerWidget {
  final String userId;

  const _UserPosts({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPosts = ref.watch(_userPostsProvider(userId));
    return asyncPosts.when(
      data: (page) {
        if (page.content.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('Chưa có bài viết nào',
                style: TextStyle(color: Colors.grey.shade600)),
          );
        }
        return Column(
          children: page.content
              .map((p) => PostCard(
                    key: ValueKey(p.id),
                    post: p,
                    onDeleted: () => ref.invalidate(_userPostsProvider(userId)),
                  ))
              .toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Không tải được bài viết: $e'),
    );
  }
}

/// Runs [action] and shows a SnackBar instead of letting a failure (e.g.
/// the backend rejecting a duplicate friend request) become an uncaught
/// error that reaches the app's global crash handler.
Future<void> _runSafely(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

final _userPostsProvider =
    FutureProvider.family<PageResponse<Post>, String>((ref, userId) {
  return ref.read(postRepositoryProvider).byAuthor(userId);
});
