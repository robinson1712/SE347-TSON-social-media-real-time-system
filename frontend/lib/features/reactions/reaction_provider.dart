import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/reaction.dart';
import 'reaction_repository.dart';

class ReactionKey {
  final TargetType targetType;
  final String targetId;
  final String targetOwnerId;

  const ReactionKey({
    required this.targetType,
    required this.targetId,
    required this.targetOwnerId,
  });

  @override
  bool operator ==(Object other) =>
      other is ReactionKey &&
      other.targetType == targetType &&
      other.targetId == targetId;

  @override
  int get hashCode => Object.hash(targetType, targetId);
}

class ReactionState {
  final ReactionSummary summary;
  final ReactionType? myReaction;
  final bool loading;

  const ReactionState({
    required this.summary,
    this.myReaction,
    this.loading = false,
  });
}

class ReactionNotifier extends StateNotifier<ReactionState> {
  final ReactionRepository _repository;
  final ReactionKey key;

  ReactionNotifier(this._repository, this.key)
      : super(ReactionState(summary: ReactionSummary.empty(), loading: true)) {
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _repository.summary(key.targetType, key.targetId),
      _repository.myReaction(key.targetType, key.targetId),
    ]);
    if (!mounted) return;
    state = ReactionState(
      summary: results[0] as ReactionSummary,
      myReaction: (results[1] as Reaction?)?.type,
    );
  }

  Future<void> react(ReactionType type) async {
    final previous = state;
    if (previous.myReaction == type) {
      await _repository.delete(key.targetType, key.targetId);
    } else {
      await _repository.upsert(UpsertReactionRequest(
        targetType: key.targetType,
        targetId: key.targetId,
        targetOwnerId: key.targetOwnerId,
        type: type,
      ));
    }
    await _load();
  }
}

final reactionRepositoryProvider = Provider((ref) => ReactionRepository());

final reactionProvider =
    StateNotifierProvider.family<ReactionNotifier, ReactionState, ReactionKey>(
  (ref, key) => ReactionNotifier(ref.watch(reactionRepositoryProvider), key),
);
