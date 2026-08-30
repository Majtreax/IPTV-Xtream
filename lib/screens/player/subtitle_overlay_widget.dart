import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_xtream/app/theme.dart';
import 'package:iptv_xtream/utils/language_helper.dart';

class SubtitleOverlay extends StatefulWidget {
  final List<Map<String, dynamic>> subtitles;
  final int activeSubtitleIndex;
  final ValueChanged<int> onSubtitleSelected;
  final VoidCallback onClose;
  final double rightOffset;

  const SubtitleOverlay({
    super.key,
    required this.subtitles,
    required this.activeSubtitleIndex,
    required this.onSubtitleSelected,
    required this.onClose,
    this.rightOffset = 24,
  });

  @override
  State<SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends State<SubtitleOverlay> {
  final _focusNode = FocusNode(debugLabel: 'SubtitleOverlay');
  final _scrollController = ScrollController();
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusedIndex = widget.activeSubtitleIndex < 0 ? 0 : widget.activeSubtitleIndex;
    if (_focusedIndex >= widget.subtitles.length) {
      _focusedIndex = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      if (_focusedIndex > 0 && _scrollController.hasClients) {
        _scrollController.jumpTo(
          (_focusedIndex * 36.0).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _moveFocus(int delta) {
    setState(() {
      _focusedIndex = (_focusedIndex + delta).clamp(
        0,
        widget.subtitles.length - 1,
      );
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        (_focusedIndex * 36.0).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: widget.rightOffset,
      bottom: 112,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _moveFocus(-1);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _moveFocus(1);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA) {
              widget.onSubtitleSelected(_focusedIndex);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.closedCaptionToggle ||
                event.logicalKey == LogicalKeyboardKey.subtitle) {
              widget.onClose();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedBuilder(
          animation: _focusNode,
          builder: (context, child) {
            final isFocused = _focusNode.hasFocus;
            return Container(
              width: 76,
              constraints: const BoxConstraints(maxHeight: 340),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: buildDialogDecoration(radius: 14).copyWith(
                border: Border.all(
                  color: isFocused ? kAccentPurple : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(widget.subtitles.length, (index) {
                      final sub = widget.subtitles[index];
                      final label = LanguageHelper.getLabel(sub, index);
                      final isActive = index == widget.activeSubtitleIndex;
                      final isItemFocused = index == _focusedIndex && isFocused;

                      return GestureDetector(
                        onTap: () {
                          _focusNode.requestFocus();
                          widget.onSubtitleSelected(index);
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _focusedIndex = index),
                          child: Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isItemFocused || isActive
                                  ? kAccentPurple.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isItemFocused
                                    ? kAccentPurple
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isActive
                                    ? kAccentPurple
                                    : (isItemFocused ? Colors.white : kTextSecondary),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
