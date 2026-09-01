import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/auth/current_user_widgets.dart';
import '../../features/chat/chat_dropdown_button.dart';
import '../../features/chat/chat_provider.dart';
import '../../features/chat/floating_chat_windows.dart';
import '../../features/fanpages/fanpage_provider.dart';
import '../../features/feed/feed_provider.dart';
import '../../features/groups/group_provider.dart';
import '../../features/notifications/notification_bell_button.dart';
import '../../features/profile/friend_requests_button.dart';
import '../../features/search/search_bar_widget.dart';
import 'right_sidebar.dart';

/// Facebook-style shell: top bar (logo, search, friend requests, profile
/// menu), left nav sidebar (with disabled "coming soon" entries for
/// features not yet built), and a single vertical-scrolling center column
/// for the page content — the layout this app is meant to share with the
/// future mobile build, so the center column stays a single flow, not a
/// dashboard grid.
class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final showSidebars = width >= 900;
    final myId = ref.watch(currentAccountIdProvider);

    return Stack(
      children: [
        _buildScaffold(context, ref, showSidebars, myId),
        const Positioned.fill(child: FloatingChatWindows()),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context, WidgetRef ref, bool showSidebars, String? myId) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            Text('social',
                style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 22)),
            const SizedBox(width: 16),
            if (showSidebars) const SearchBarWidget(),
          ],
        ),
        actions: [
          if (!showSidebars)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SearchBarWidget(),
                  ),
                ),
              ),
            ),
          const FriendRequestsButton(),
          const ChatDropdownButton(),
          const NotificationBellButton(),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              context.go('/');
              ref.read(feedProvider.notifier).refresh();
            },
          ),
          PopupMenuButton<String>(
            icon: const Padding(
              padding: EdgeInsets.all(4),
              child: CurrentUserAvatar(radius: 16),
            ),
            onSelected: (value) async {
              if (value == 'profile' && myId != null) {
                context.push('/profile/$myId');
              } else if (value == 'friends') {
                context.push('/friends');
              } else if (value == 'logout') {
                await ref.read(authProvider.notifier).logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('Trang cá nhân')),
              PopupMenuItem(value: 'friends', child: Text('Bạn bè')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSidebars)
            SizedBox(
              width: 260,
              child: _LeftNav(myId: myId, isAdmin: ref.watch(authProvider).account?.isAdmin ?? false),
            ),
          Expanded(
            flex: 3,
            child: child,
          ),
          if (showSidebars)
            const SizedBox(
              width: 280,
              child: RightSidebar(),
            ),
        ],
      ),
    );
  }
}

class _LeftNav extends ConsumerWidget {
  final String? myId;
  final bool isAdmin;

  const _LeftNav({required this.myId, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatUnread = ref.watch(chatUnreadCountProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        _NavItem(
          icon: Icons.home,
          label: 'Bảng tin',
          onTap: () {
            context.go('/');
            ref.read(feedProvider.notifier).refresh();
          },
        ),
        if (myId != null)
          _NavItem(
            icon: Icons.person,
            label: 'Trang cá nhân',
            onTap: () => context.push('/profile/$myId'),
          ),
        _NavItem(
          icon: Icons.people,
          label: 'Bạn bè',
          onTap: () => context.push('/friends'),
        ),
        const Divider(),
        _NavItem(
          icon: Icons.groups_outlined,
          label: 'Nhóm',
          onTap: () => context.push('/groups'),
        ),
        _NavItem(
          icon: Icons.flag_outlined,
          label: 'Trang (Fanpage)',
          onTap: () => context.push('/pages'),
        ),
        _NavItem(
          icon: Icons.movie_outlined,
          label: 'Reels',
          onTap: () => context.push('/reels'),
        ),
        _NavItem(
          icon: Icons.favorite_border,
          label: 'Hẹn hò',
          onTap: () => context.push('/dating'),
        ),
        _NavItem(
          icon: Icons.chat_bubble_outline,
          label: 'Trò chuyện',
          badgeCount: chatUnread,
          onTap: () => context.push('/chat'),
        ),
        if (isAdmin) ...[
          const Divider(),
          _NavItem(
            icon: Icons.shield_outlined,
            label: 'Kiểm duyệt (Admin)',
            onTap: () => context.push('/admin/reports'),
          ),
        ],
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Lối tắt của bạn',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade600)),
        ),
        const _ShortcutsList(),
      ],
    );
  }
}

/// Left-nav shortcuts, Facebook-style: groups joined + pages followed,
/// combined into one list, tappable straight to each one's detail page.
class _ShortcutsList extends ConsumerWidget {
  const _ShortcutsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(myGroupsProvider);
    final pagesAsync = ref.watch(myFollowedFanpagesProvider);

    final groups = groupsAsync.value?.content ?? const [];
    final pages = pagesAsync.value?.content ?? const [];
    final stillLoading = (groupsAsync.isLoading && groups.isEmpty) ||
        (pagesAsync.isLoading && pages.isEmpty);

    if (stillLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (groups.isEmpty && pages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('Chưa có nhóm hoặc trang nào',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      );
    }

    return Column(
      children: [
        for (final g in groups)
          _ShortcutTile(
            name: g.name,
            avatarUrl: g.avatarUrl,
            icon: Icons.groups,
            onTap: () => context.push('/groups/${g.id}'),
          ),
        for (final p in pages)
          _ShortcutTile(
            name: p.name,
            avatarUrl: p.avatarUrl,
            icon: Icons.flag,
            onTap: () => context.push('/pages/${p.id}'),
          ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final IconData icon;
  final VoidCallback onTap;

  const _ShortcutTile({
    required this.name,
    required this.avatarUrl,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: avatarUrl != null
            ? Image.network(avatarUrl!, width: 32, height: 32, fit: BoxFit.cover)
            : Container(
                width: 32,
                height: 32,
                decoration:
                    BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 18, color: Colors.grey.shade600),
              ),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
      onTap: onTap,
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool comingSoon;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.comingSoon = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: comingSoon ? Colors.grey.shade400 : null),
      title: Text(
        label,
        style: comingSoon ? TextStyle(color: Colors.grey.shade400) : null,
      ),
      trailing: comingSoon
          ? Text('Sắp có', style: TextStyle(fontSize: 11, color: Colors.grey.shade400))
          : badgeCount > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 20),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                )
              : null,
      enabled: !comingSoon,
      onTap: onTap,
    );
  }
}

