import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/avatar.dart';
import 'search_repository.dart';

class SearchResultsPage extends ConsumerStatefulWidget {
  final String query;

  const SearchResultsPage({super.key, required this.query});

  @override
  ConsumerState<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends ConsumerState<SearchResultsPage> {
  late final TextEditingController _controller = TextEditingController(text: widget.query);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncResults = ref.watch(_searchResultsProvider(widget.query));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(hintText: 'Tìm kiếm...', border: InputBorder.none),
          onSubmitted: (q) {
            if (q.trim().isNotEmpty) context.go('/search?q=${Uri.encodeQueryComponent(q.trim())}');
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: asyncResults.when(
            data: (results) {
              if (results.isEmpty) {
                return Center(
                  child: Text('Không tìm thấy kết quả cho "${widget.query}"',
                      style: TextStyle(color: Colors.grey.shade600)),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (results.users.isNotEmpty) ...[
                    _SectionHeader('Mọi người'),
                    ...results.users.map((u) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: Avatar(url: u.avatarUrl, name: u.fullName),
                            title: Text(u.fullName),
                            onTap: () => context.push('/profile/${u.id}'),
                          ),
                        )),
                  ],
                  if (results.groups.isNotEmpty) ...[
                    _SectionHeader('Nhóm'),
                    ...results.groups.map((g) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: Avatar(url: g.avatarUrl, name: g.name),
                            title: Text(g.name),
                            subtitle: g.description != null ? Text(g.description!, maxLines: 1) : null,
                            onTap: () => context.push('/groups/${g.id}'),
                          ),
                        )),
                  ],
                  if (results.pages.isNotEmpty) ...[
                    _SectionHeader('Trang'),
                    ...results.pages.map((p) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: Avatar(url: p.avatarUrl, name: p.name),
                            title: Text(p.name),
                            subtitle: p.category != null ? Text(p.category!) : null,
                            onTap: () => context.push('/pages/${p.id}'),
                          ),
                        )),
                  ],
                  if (results.posts.isNotEmpty) ...[
                    _SectionHeader('Bài viết'),
                    ...results.posts.map((p) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: const Icon(Icons.article_outlined),
                            title: Text(p.content ?? '(không có nội dung)', maxLines: 2),
                            onTap: () => context.push('/post/${p.id}'),
                          ),
                        )),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi: $e')),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

final _searchResultsProvider = FutureProvider.family((ref, String q) {
  return ref.read(searchRepositoryProvider).search(q, limit: 20);
});
