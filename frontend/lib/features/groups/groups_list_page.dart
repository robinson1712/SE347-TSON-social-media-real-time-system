import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../shared/widgets/avatar.dart';
import 'create_group_dialog.dart';
import 'group_provider.dart';

class GroupsListPage extends ConsumerStatefulWidget {
  const GroupsListPage({super.key});

  @override
  ConsumerState<GroupsListPage> createState() => _GroupsListPageState();
}

class _GroupsListPageState extends ConsumerState<GroupsListPage> with SingleTickerProviderStateMixin {
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
        title: const Text('Nhóm'),
        bottom: TabBar(controller: _tabController, tabs: const [
          Tab(text: 'Khám phá'),
          Tab(text: 'Nhóm của tôi'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showCreateGroupDialog(context),
          ),
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
                          prefixIcon: Icon(Icons.search), hintText: 'Tìm nhóm...'),
                      onSubmitted: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                  Expanded(child: _GroupGrid(nameFilter: _query)),
                ],
              ),
              const _MyGroupsGrid(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupGrid extends ConsumerWidget {
  final String? nameFilter;

  const _GroupGrid({this.nameFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGroups = ref.watch(groupListProvider(nameFilter));
    return asyncGroups.when(
      data: (page) => page.content.isEmpty
          ? Center(child: Text('Không có nhóm nào', style: TextStyle(color: Colors.grey.shade600)))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: page.content.map((g) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Avatar(url: g.avatarUrl, name: g.name),
                      title: Text(g.name),
                      subtitle: Text('${g.memberCount} thành viên · ${g.privacy.label}'),
                      onTap: () => context.push('/groups/${g.id}'),
                    ),
                  )).toList(),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
    );
  }
}

class _MyGroupsGrid extends ConsumerWidget {
  const _MyGroupsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGroups = ref.watch(myGroupsProvider);
    return asyncGroups.when(
      data: (page) => page.content.isEmpty
          ? Center(
              child: Text('Bạn chưa tham gia nhóm nào', style: TextStyle(color: Colors.grey.shade600)))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: page.content.map((g) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Avatar(url: g.avatarUrl, name: g.name),
                      title: Text(g.name),
                      subtitle: Text('${g.memberCount} thành viên'),
                      onTap: () => context.push('/groups/${g.id}'),
                    ),
                  )).toList(),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
    );
  }
}
