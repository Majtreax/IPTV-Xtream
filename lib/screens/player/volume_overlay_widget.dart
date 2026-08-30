import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_xtream/app/theme.dart';

class VolumeOverlay extends StatefulWidget {
  final double initialVolume;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onClose;
  final double rightOffset;

  const VolumeOverlay({
    super.key,
    required this.initialVolume,
    required this.onVolumeChanged,
    required this.onClose,
    this.rightOffset = 82,
  });

  @override
  State<VolumeOverlay> createState() => _VolumeOverlayState();
}

class _VolumeOverlayState extends State<VolumeOverlay> {
  late double _currentVolume;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentVolume = widget.initialVolume;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _changeVolume(int delta) {
    setState(() {
      _currentVolume += delta * 20;
      _currentVolume = _currentVolume.clamp(0.0, 100.0);
    });
    widget.onVolumeChanged(_currentVolume);
  }

  @override
  Widget build(BuildContext context) {
    final activeBars = (_currentVolume / 20).round();

    return Positioned(
      right: widget.rightOffset,
      bottom: 112,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _changeVolume(1);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _changeVolume(-1);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter) {
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
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: buildDialogDecoration(radius: 14).copyWith(
                border: Border.all(
                  color: isFocused ? kAccentPurple : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    verticalDirection: VerticalDirection.up,
                    children: List.generate(5, (index) {
                      final isActive = index < activeBars;
                      return GestureDetector(
                        onTap: () {
                          _focusNode.requestFocus();
                          final targetVolume = (index + 1) * 20.0;
                          setState(() {
                            _currentVolume = targetVolume;
                          });
                          widget.onVolumeChanged(_currentVolume);
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 24,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? kAccentPurple
                                  : kTextDisabled.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: kAccentPurple.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
