import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import 'reaction_provider.dart';

/// Facebook-style reaction control: a plain "Thích" button that reacts with
/// `like` on tap, and reveals an emoji row on hover (desktop web) or
/// long-press (touch) to pick a specific reaction type.
class ReactionPicker extends ConsumerStatefulWidget {
  final ReactionKey reactionKey;

  const ReactionPicker({super.key, required this.reactionKey});

  @override
  ConsumerState<ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends ConsumerState<ReactionPicker> {
  OverlayEntry? _entry;
  Timer? _hideTimer;
  final _layerLink = LayerLink();

  void _cancelHide() => _hideTimer?.cancel();

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 250), _removePicker);
  }

  void _removePicker() {
    _entry?.remove();
    _entry = null;
  }

  void _showPicker() {
    if (_entry != null) return;
    _entry = OverlayEntry(
      builder: (context) => Positioned(
        width: 260,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -52),
          child: MouseRegion(
            onEnter: (_) => _cancelHide(),
            onExit: (_) => _scheduleHide(),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ReactionType.values.map((type) {
                      return InkWell(
                        onTap: () {
                          ref.read(reactionProvider(widget.reactionKey).notifier).react(type);
                          _removePicker();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(type.emoji, style: const TextStyle(fontSize: 26)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reactionProvider(widget.reactionKey));
    final mine = state.myReaction;

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          _cancelHide();
          _showPicker();
        },
        onExit: (_) => _scheduleHide(),
        child: GestureDetector(
          onLongPress: _showPicker,
          child: TextButton.icon(
            onPressed: () => ref
                .read(reactionProvider(widget.reactionKey).notifier)
                .react(mine ?? ReactionType.like),
            icon: Text(
              mine?.emoji ?? '👍',
              style: const TextStyle(fontSize: 16),
            ),
            label: Text(
              mine == null ? 'Thích' : _label(mine),
              style: TextStyle(
                color: mine == null ? Colors.grey.shade700 : Theme.of(context).primaryColor,
                fontWeight: mine == null ? FontWeight.normal : FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _label(ReactionType type) {
    switch (type) {
      case ReactionType.like:
        return 'Thích';
      case ReactionType.love:
        return 'Yêu thích';
      case ReactionType.haha:
        return 'Haha';
      case ReactionType.wow:
        return 'Wow';
      case ReactionType.sad:
        return 'Buồn';
      case ReactionType.angry:
        return 'Phẫn nộ';
    }
  }
}

/// Small read-only summary row (emoji stack + total count) shown above the
/// action buttons on a post/comment card.
class ReactionSummaryRow extends ConsumerWidget {
  final ReactionKey reactionKey;

  const ReactionSummaryRow({super.key, required this.reactionKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reactionProvider(reactionKey));
    if (state.summary.total == 0) return const SizedBox.shrink();

    final topTypes = state.summary.counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ...topTypes.take(3).map(
                (e) => Text(e.key.emoji, style: const TextStyle(fontSize: 14)),
              ),
          const SizedBox(width: 4),
          Text('${state.summary.total}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }
}
