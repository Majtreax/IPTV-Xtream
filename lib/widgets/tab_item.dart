import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_xtream/app/theme.dart';

class TabItem extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onFocus;
  final VoidCallback? onFocusUp;
  final bool autofocus;
  final FocusNode? focusNode;

  const TabItem({
    super.key,
    required this.title,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.onFocus,
    this.onFocusUp,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<TabItem> {
  bool _isFocused = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _focusNode.requestFocus();
        widget.onTap();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Focus(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onFocusChange: (focused) {
            setState(() => _isFocused = focused);
            
            if (focused) {
              final keys = HardwareKeyboard.instance.logicalKeysPressed;
              final cameFromUp = keys.contains(LogicalKeyboardKey.arrowUp);
              
              if (cameFromUp && !widget.isActive && widget.onFocusUp != null) {
                // REDIRECT FOCUS IF NAVIGATING UP TO INACTIVE TAB
                widget.onFocusUp!();
              } else if (widget.onFocus != null) {
                // AUTO-SWITCH TAB ON FOCUS
                widget.onFocus!();
              }
            }
          },
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter) {
                widget.onTap();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                node.nextFocus();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                node.previousFocus();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: (widget.isActive || _isFocused) ? 1.0 : 0.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                        bottom: Radius.circular(4),
                      ),
                      boxShadow: buildGlowShadow(
                        color: kAccentPurple,
                        alpha: _isFocused ? 0.45 : 0.18,
                        blurRadius: 22,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _isFocused
                      ? kAccentPurple.withValues(alpha: 0.2)
                      : (widget.isActive
                            ? kAccentPurple.withValues(alpha: 0.1)
                            : Colors.transparent),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                    bottom: Radius.circular(4),
                  ),
                  border: Border.all(
                    color: _isFocused
                        ? kAccentPurple
                        : (widget.isActive
                              ? kTextDisabled.withValues(alpha: 0.1)
                              : Colors.transparent),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      color: _isFocused
                          ? kAccentPurple
                          : (widget.isActive ? kTextPrimary : kTextSecondary),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 22,
                        letterSpacing: 1.2,
                        fontWeight: widget.isActive || _isFocused
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: _isFocused
                            ? kAccentPurple
                            : (widget.isActive ? kTextPrimary : kTextSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
