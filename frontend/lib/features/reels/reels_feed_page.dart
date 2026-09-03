import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/reel_video_player.dart';
import '../../shared/widgets/user_inline.dart';
import '../reactions/reaction_picker.dart';
import '../reactions/reaction_provider.dart';
import '../../core/models/enums.dart';
import 'create_reel_dialog.dart';
import 'reel_provider.dart';

class ReelsFeedPage extends ConsumerStatefulWidget {
  const ReelsFeedPage({super.key});

  @override
  ConsumerState<ReelsFeedPage> createState() => _ReelsFeedPageState();
}

class _ReelsFeedPageState extends ConsumerState<ReelsFeedPage> {
  final _pageController = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reelFeedProvider);

    // No AppBar — AppShell already owns the app's one persistent top bar,
    // and this page is meant to be an immersive full-bleed video view (like
    // Reels/TikTok) where a second bar just eats into that. The "+" create
    // button that used to live in the AppBar's actions is real
    // functionality, so it moves to a floating button over the video
    // instead of disappearing with the bar.
    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white24,
        foregroundColor: Colors.white,
        onPressed: () => showCreateReelDialog(context),
        child: const Icon(Icons.add),
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.reels.isEmpty
              ? const Center(
                  child: Text('Chưa có reel nào', style: TextStyle(color: Colors.white70)))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: state.reels.length,
                      onPageChanged: (index) {
                        setState(() => _current = index);
                        ref.read(reelActionsProvider).view(state.reels[index].id);
                        if (index > state.reels.length - 3) {
                          ref.read(reelFeedProvider.notifier).loadMore();
                        }
                      },
                      itemBuilder: (context, index) {
                        final reel = state.reels[index];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ReelVideoPlayer(videoUrl: reel.videoUrl, autoplay: index == _current),
                            Positioned(
                              left: 12,
                              right: 60,
                              bottom: 24,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  UserInline(
                                    userId: reel.authorId,
                                    avatarRadius: 16,
                                    nameStyle: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  if (reel.caption != null && reel.caption!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(reel.caption!,
                                          style: const TextStyle(color: Colors.white)),
                                    ),
                                ],
                              ),
                            ),
                            Positioned(
                              right: 12,
                              bottom: 24,
                              child: Column(
                                children: [
                                  Theme(
                                    data: ThemeData.dark(),
                                    child: ReactionPicker(
                                      reactionKey: ReactionKey(
                                        targetType: TargetType.reel,
                                        targetId: reel.id,
                                        targetOwnerId: reel.authorId,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Icon(Icons.remove_red_eye, color: Colors.white70, size: 20),
                                  Text('${reel.viewCount}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}
