import 'package:flutter/material.dart';

import '../../core/models/user_profile.dart';
import 'avatar.dart';

/// A [TextField] with Facebook-style `@name` autocomplete: typing `@`
/// followed by letters opens a dropdown of matching [candidates] (friends),
/// picking one inserts their name as text and records their id into
/// [mentionedUserIds] — the caller merges that set into `taggedUserIds` on
/// submit. Purely a client-side text/id association: the backend has no
/// concept of parsing `@mentions` out of free-text content, so this widget
/// is what turns typed mentions into the same `taggedUserIds` field the
/// existing tag-picker chips write to.
class MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final List<UserProfile> candidates;
  final Set<String> mentionedUserIds;
  final InputDecoration? decoration;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  const MentionTextField({
    super.key,
    required this.controller,
    required this.candidates,
    required this.mentionedUserIds,
    this.decoration,
    this.maxLines = 1,
    this.minLines,
    this.onSubmitted,
    this.focusNode,
  });

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  final _layerLink = LayerLink();
  FocusNode? _ownedFocusNode;
  OverlayEntry? _entry;
  int? _atIndex;

  FocusNode get _focusNode => widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _removeOverlay();
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      _removeOverlay();
      return;
    }

    // Scan backward from the cursor for an unclosed "@token".
    var start = cursor;
    while (start > 0 && text[start - 1] != '@' && text[start - 1] != ' ' && text[start - 1] != '\n') {
      start--;
    }
    final hasAt = start > 0 && text[start - 1] == '@';
    if (!hasAt) {
      _removeOverlay();
      return;
    }
    _atIndex = start - 1;
    final query = text.substring(start, cursor).toLowerCase();
    final matches = widget.candidates
        .where((c) => c.fullName.toLowerCase().contains(query))
        .take(6)
        .toList();

    if (matches.isEmpty) {
      _removeOverlay();
    } else {
      _showOverlay(matches);
    }
  }

  void _pick(UserProfile user) {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    if (_atIndex == null || cursor < 0) return;
    final before = text.substring(0, _atIndex!);
    final after = text.substring(cursor);
    final inserted = '@${user.fullName} ';
    final newText = '$before$inserted$after';
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: before.length + inserted.length),
    );
    widget.mentionedUserIds.add(user.id);
    _removeOverlay();
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
    _atIndex = null;
  }

  void _showOverlay(List<UserProfile> matches) {
    _removeOverlay();
    _entry = OverlayEntry(
      builder: (context) => Positioned(
        width: 260,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: matches
                    .map((u) => ListTile(
                          dense: true,
                          leading: Avatar(url: u.avatarUrl, name: u.fullName, radius: 14),
                          title: Text(u.fullName),
                          onTap: () => _pick(u),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: widget.decoration,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
