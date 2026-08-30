import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_xtream/app/theme.dart';

class TvCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSelect;
  final bool autofocus;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final bool scaleOnFocus;

  const TvCard({
    super.key,
    required this.child,
    this.onSelect,
    this.autofocus = false,
    this.focusNode,
    this.onKeyEvent,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.all(12),
    this.backgroundColor,
    this.scaleOnFocus = true,
  });

  @override
  State<TvCard> createState() => _TvCardState();
}

class _TvCardState extends State<TvCard> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.onKeyEvent != null) {
      final res = widget.onKeyEvent!(node, event);
      if (res != KeyEventResult.ignored) return res;
    }
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
      widget.onSelect?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? kSurfaceCard;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _focusNode.requestFocus();
        widget.onSelect?.call();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Focus(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onKeyEvent: _handleKeyEvent,
          onFocusChange: (focused) {
            setState(() => _isFocused = focused);
            if (focused) {
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeInOutCubic,
              );
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: widget.scaleOnFocus
                ? (Matrix4.identity()
                  ..scaleByDouble(
                    _isFocused ? 1.05 : 1.0,
                    _isFocused ? 1.05 : 1.0,
                    1.0,
                    1.0,
                  ))
                : Matrix4.identity(),
            transformAlignment: Alignment.center,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: _isFocused || _isHovered
                  ? kAccentPurple.withValues(alpha: 0.15)
                  : bgColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _isFocused || _isHovered
                    ? kAccentPurple
                    : Colors.transparent,
                width: 2,
              ),
              boxShadow: _isFocused || _isHovered
                  ? buildGlowShadow(color: kAccentPurple, alpha: 0.25)
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
