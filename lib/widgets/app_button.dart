import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_xtream/app/theme.dart';

class AppButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool autofocus;
  final FocusNode? focusNode;
  final double? width;
  final EdgeInsetsGeometry padding;
  final bool primary;
  final bool isVertical;
  final double fontSize;
  final double iconSize;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.autofocus = false,
    this.focusNode,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
    this.primary = false,
    this.isVertical = false,
    this.fontSize = 17,
    this.iconSize = 22,
  });

  @override
  State<AppButton> createState() => _FocusableButtonState();
}

class _FocusableButtonState extends State<AppButton> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _isFocused = _focusNode.hasFocus;
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter)) {
      widget.onPressed?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _focusNode.requestFocus();
        widget.onPressed?.call();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Focus(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onKeyEvent: _handleKeyEvent,
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: widget.width,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.primary
                  ? (_isFocused ? kFocusedButtonColor : kPrimaryButtonColor)
                  : (_isFocused
                        ? kFocusedButtonColor.withValues(alpha: 0.2)
                        : kSecondaryButtonColor),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isFocused
                    ? kFocusedButtonColor
                    : (widget.primary
                          ? Colors.transparent
                          : kTextDisabled.withValues(alpha: 0.1)),
                width: _isFocused ? 2 : 1,
              ),
              boxShadow: widget.primary
                  ? buildGlowShadow(
                      color: kAccentPurple,
                      alpha: _isFocused ? 0.4 : 0.15,
                      blurRadius: _isFocused ? 28 : 16,
                      offset: const Offset(0, 4),
                    )
                  : _isFocused
                  ? buildGlowShadow(
                      color: kAccentPurple,
                      alpha: 0.25,
                      blurRadius: 20,
                      offset: Offset.zero,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: widget.isVertical
                ? _buildVerticalLayout()
                : _buildHorizontalLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalLayout() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(
            widget.icon,
            size: widget.iconSize,
            color: _isFocused ? Colors.white : kTextSecondary,
          ),
          if (widget.label.isNotEmpty) const SizedBox(width: 10),
        ],
        if (widget.label.isNotEmpty)
          Text(
            widget.label,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w600,
              color: _isFocused ? Colors.white : kTextSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildVerticalLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(
            widget.icon,
            size: widget.iconSize,
            color: _isFocused ? Colors.white : kTextSecondary,
          ),
          if (widget.label.isNotEmpty) const SizedBox(height: 8),
        ],
        if (widget.label.isNotEmpty)
          Text(
            widget.label,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w600,
              color: _isFocused ? Colors.white : kTextSecondary,
            ),
          ),
      ],
    );
  }
}
