import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/comment.dart';
import 'comment_repository.dart';

class CommentSectionState {
  final List<Comment> topLevel;
  final Map<String, List<Comment>> repliesByParent;
  final Set<String> expandedParents;
  final bool loading;

  const CommentSectionState({
    this.topLevel = const [],
    this.repliesByParent = const {},
    this.expandedParents = const {},
    this.loading = false,
  });

  CommentSectionState copyWith({
    List<Comment>? topLevel,
    Map<String, List<Comment>>? repliesByParent,
    Set<String>? expandedParents,
    bool? loading,
  }) =>
      CommentSectionState(
        topLevel: topLevel ?? this.topLevel,
        repliesByParent: repliesByParent ?? this.repliesByParent,
        expandedParents: expandedParents ?? this.expandedParents,
        loading: loading ?? this.loading,
      );
}

class CommentSectionNotifier extends StateNotifier<CommentSectionState> {
  final CommentRepository _repository;
  final String postId;
  final String postOwnerId;

  CommentSectionNotifier(this._repository, this.postId, this.postOwnerId)
      : super(const CommentSectionState(loading: true)) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true);
    final page = await _repository.topLevel(postId);
    if (!mounted) return;
    state = state.copyWith(topLevel: page.content, loading: false);
  }

  Future<void> addComment(String content, {String? parentCommentId}) async {
    final comment = await _repository.create(CreateCommentRequest(
      postId: postId,
      content: content,
      parentCommentId: parentCommentId,
    ));
    if (!mounted) return;
    if (parentCommentId == null) {
      state = state.copyWith(topLevel: [comment, ...state.topLevel]);
    } else {
      final replies = List<Comment>.from(
          state.repliesByParent[parentCommentId] ?? const []);
      replies.add(comment);
      state = state.copyWith(
        repliesByParent: {...state.repliesByParent, parentCommentId: replies},
        expandedParents: {...state.expandedParents, parentCommentId},
      );
    }
  }

  Future<void> toggleReplies(String parentId) async {
    final expanded = Set<String>.from(state.expandedParents);
    if (expanded.contains(parentId)) {
      expanded.remove(parentId);
      state = state.copyWith(expandedParents: expanded);
      return;
    }
    expanded.add(parentId);
    state = state.copyWith(expandedParents: expanded);
    if (!state.repliesByParent.containsKey(parentId)) {
      final page = await _repository.replies(parentId);
      if (!mounted) return;
      state = state.copyWith(
        repliesByParent: {...state.repliesByParent, parentId: page.content},
      );
    }
  }

  Future<void> deleteComment(String id, {String? parentCommentId}) async {
    await _repository.delete(id);
    if (!mounted) return;
    if (parentCommentId == null) {
      state = state.copyWith(
        topLevel: state.topLevel.where((c) => c.id != id).toList(),
      );
    } else {
      final replies = (state.repliesByParent[parentCommentId] ?? const [])
          .where((c) => c.id != id)
          .toList();
      state = state.copyWith(
        repliesByParent: {...state.repliesByParent, parentCommentId: replies},
      );
    }
  }
}

final commentRepositoryProvider = Provider((ref) => CommentRepository());

class CommentSectionKey {
  final String postId;
  final String postOwnerId;

  const CommentSectionKey(
      {required this.postId, required this.postOwnerId});

  @override
  bool operator ==(Object other) =>
      other is CommentSectionKey && other.postId == postId;

  @override
  int get hashCode => postId.hashCode;
}

final commentSectionProvider = StateNotifierProvider.family<
    CommentSectionNotifier, CommentSectionState, CommentSectionKey>(
  (ref, key) => CommentSectionNotifier(
    ref.watch(commentRepositoryProvider),
    key.postId,
    key.postOwnerId,
  ),
);
