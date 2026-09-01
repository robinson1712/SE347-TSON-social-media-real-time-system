import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/chat/chat_thread_page.dart';
import '../../features/chat/conversations_page.dart';
import '../../features/dating/dating_home_page.dart';
import '../../features/fanpages/fanpage_detail_page.dart';
import '../../features/fanpages/fanpages_list_page.dart';
import '../../features/feed/feed_page.dart';
import '../../features/groups/group_detail_page.dart';
import '../../features/groups/groups_list_page.dart';
import '../../features/moderation/admin_reports_page.dart';
import '../../features/posts/post_detail_page.dart';
import '../../features/profile/friends_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/reels/reels_feed_page.dart';
import '../../features/search/search_results_page.dart';
import '../../shared/widgets/app_shell.dart';

class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _GoRouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final status = authState.status;
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final onSplash = state.matchedLocation == '/splash';

      if (status == AuthStatus.unknown) return onSplash ? null : '/splash';
      if (status == AuthStatus.unauthenticated) return loggingIn ? null : '/login';
      if (status == AuthStatus.authenticated && (loggingIn || onSplash)) return '/';

      if (state.matchedLocation.startsWith('/admin') &&
          !(authState.account?.isAdmin ?? false)) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
          path: '/register', builder: (context, state) => const RegisterPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const FeedPage()),
          GoRoute(
            path: '/post/:id',
            builder: (context, state) =>
                PostDetailPage(postId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/profile/:id',
            builder: (context, state) =>
                ProfilePage(userId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/friends', builder: (context, state) => const FriendsPage()),
          GoRoute(path: '/groups', builder: (context, state) => const GroupsListPage()),
          GoRoute(
            path: '/groups/:id',
            builder: (context, state) =>
                GroupDetailPage(groupId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/pages', builder: (context, state) => const FanpagesListPage()),
          GoRoute(
            path: '/pages/:id',
            builder: (context, state) =>
                FanpageDetailPage(pageId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/reels', builder: (context, state) => const ReelsFeedPage()),
          GoRoute(path: '/dating', builder: (context, state) => const DatingHomePage()),
          GoRoute(path: '/chat', builder: (context, state) => const ConversationsPage()),
          GoRoute(
            path: '/chat/:id',
            builder: (context, state) =>
                ChatThreadPage(conversationId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) =>
                SearchResultsPage(query: state.uri.queryParameters['q'] ?? ''),
          ),
          GoRoute(
              path: '/admin/reports', builder: (context, state) => const AdminReportsPage()),
        ],
      ),
    ],
  );
});
