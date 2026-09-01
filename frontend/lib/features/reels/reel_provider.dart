import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/page_response.dart';
import '../../core/models/reel.dart';
import 'reel_repository.dart';

class ReelFeedState {
  final List<Reel> reels;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final int page;

  const ReelFeedState({
    this.reels = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.page = 0,
  });

  ReelFeedState copyWith({
    List<Reel>? reels,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    int? page,
  }) =>
      ReelFeedState(
        reels: reels ?? this.reels,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
      );
}

class ReelFeedNotifier extends StateNotifier<ReelFeedState> {
  final ReelRepository _repository;
  static const _pageSize = 10;

  ReelFeedNotifier(this._repository) : super(const ReelFeedState()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true);
    try {
      final page = await _repository.feed(page: 0, size: _pageSize);
      if (!mounted) return;
      state = ReelFeedState(reels: page.content, page: 0, hasMore: !page.last);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(loading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final nextPage = state.page + 1;
      final page = await _repository.feed(page: nextPage, size: _pageSize);
      if (!mounted) return;
      state = state.copyWith(
        reels: [...state.reels, ...page.content],
        page: nextPage,
        hasMore: !page.last,
        loadingMore: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(loadingMore: false);
    }
  }
}

final reelFeedProvider = StateNotifierProvider<ReelFeedNotifier, ReelFeedState>(
  (ref) => ReelFeedNotifier(ref.watch(reelRepositoryProvider)),
);

class ReelActions {
  final Ref _ref;

  ReelActions(this._ref);

  ReelRepository get _repository => _ref.read(reelRepositoryProvider);

  Future<Reel> create(CreateReelRequest request) async {
    final reel = await _repository.create(request);
    _ref.read(reelFeedProvider.notifier).refresh();
    return reel;
  }

  Future<void> view(String id) => _repository.view(id);

  Future<void> delete(String id) => _repository.delete(id);
}

final reelActionsProvider = Provider((ref) => ReelActions(ref));

final reelsByAuthorProvider =
    FutureProvider.family<PageResponse<Reel>, String>((ref, authorId) {
  return ref.read(reelRepositoryProvider).byAuthor(authorId);
});
