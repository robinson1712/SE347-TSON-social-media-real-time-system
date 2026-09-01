import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/group.dart';
import '../../core/models/page_response.dart';
import 'group_repository.dart';

final groupListProvider =
    FutureProvider.family<PageResponse<Group>, String?>((ref, name) {
  return ref.read(groupRepositoryProvider).list(name: name);
});

final myGroupsProvider = FutureProvider<PageResponse<Group>>((ref) {
  return ref.read(groupRepositoryProvider).myGroups(size: 100);
});

final groupDetailProvider = FutureProvider.family<Group, String>((ref, id) {
  return ref.read(groupRepositoryProvider).getById(id);
});

final groupMembersProvider =
    FutureProvider.family<PageResponse<GroupMember>, String>((ref, groupId) {
  return ref.read(groupRepositoryProvider).members(groupId, size: 100);
});

class GroupActions {
  final Ref _ref;

  GroupActions(this._ref);

  GroupRepository get _repository => _ref.read(groupRepositoryProvider);

  Future<Group> create(CreateGroupRequest request) async {
    final group = await _repository.create(request);
    _ref.invalidate(myGroupsProvider);
    return group;
  }

  Future<void> join(String groupId) async {
    await _repository.join(groupId);
    _ref.invalidate(myGroupsProvider);
    _ref.invalidate(groupMembersProvider(groupId));
    _ref.invalidate(groupDetailProvider(groupId));
  }

  Future<void> leave(String groupId) async {
    await _repository.leave(groupId);
    _ref.invalidate(myGroupsProvider);
    _ref.invalidate(groupMembersProvider(groupId));
    _ref.invalidate(groupDetailProvider(groupId));
  }

  Future<void> approve(String groupId, String userId) async {
    await _repository.approve(groupId, userId);
    _ref.invalidate(groupMembersProvider(groupId));
  }

  Future<void> kick(String groupId, String userId) async {
    await _repository.kick(groupId, userId);
    _ref.invalidate(groupMembersProvider(groupId));
  }

  Future<void> changeRole(String groupId, String userId, MemberRole role) async {
    await _repository.changeRole(groupId, userId, role);
    _ref.invalidate(groupMembersProvider(groupId));
  }
}

final groupActionsProvider = Provider((ref) => GroupActions(ref));
