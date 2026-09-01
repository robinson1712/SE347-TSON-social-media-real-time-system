import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/fanpage.dart';
import '../../core/models/page_response.dart';
import '../../shared/widgets/avatar.dart';
import 'create_fanpage_dialog.dart';
import 'fanpage_provider.dart';

class FanpagesListPage extends ConsumerStatefulWidget {
  const FanpagesListPage({super.key});

  @override
  ConsumerState<FanpagesListPage> createState() => _FanpagesListPageState();
}

class _FanpagesListPageState extends ConsumerState<FanpagesListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final _searchController = TextEditingController();
  String? _query;

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang (Fanpage)'),
        bottom: TabBar(controller: _tabController, tabs: const [
          Tab(text: 'Khám phá'),
          Tab(text: 'Trang tôi quản lý'),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => showCreateFanpageDialog(context)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: TabBarView(
            controller: _tabController,
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search), hintText: 'Tìm trang...'),
                      onSubmitted: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                  Expanded(child: _FanpageGrid(provider: fanpageListProvider(_query))),
                ],
              ),
              _FanpageGrid(provider: myManagedFanpagesProvider),
            ],
          ),
        ),
      ),
    );
  }
}

class _FanpageGrid extends ConsumerWidget {
  final ProviderListenable<AsyncValue<PageResponse<Fanpage>>> provider;

  const _FanpageGrid({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      data: (page) {
        final content = page.content;
        if (content.isEmpty) {
          return Center(child: Text('Không có trang nào', style: TextStyle(color: Colors.grey.shade600)));
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: content
              .map<Widget>((p) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Avatar(url: p.avatarUrl, name: p.name),
                      title: Text(p.name),
                      subtitle: Text('${p.followerCount} người theo dõi'
                          '${p.category != null ? " · ${p.category}" : ""}'),
                      onTap: () => context.push('/pages/${p.id}'),
                    ),
                  ))
              .toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
    );
  }
}
