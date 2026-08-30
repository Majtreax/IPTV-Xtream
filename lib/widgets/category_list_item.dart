import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_xtream/app/theme.dart';

class CategoryListItem extends StatefulWidget {
  final String label;
  final bool isActive;
  final bool autofocus;
  final VoidCallback onTap;

  const CategoryListItem({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<CategoryListItem> createState() => _CategoryListItemState();
}

class _CategoryListItemState extends State<CategoryListItem> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
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
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: buildListItemDecoration(
              isFocused: _isFocused,
              isSelected: widget.isActive,
              isHovered: _isHovered,
              radius: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: kTextStyleBody.copyWith(
                      fontSize: 14,
                      color: _isFocused
                          ? kAccentPurple
                          : widget.isActive
                          ? kTextPrimary
                          : kTextSecondary,
                      fontWeight: widget.isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (widget.isActive)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: kAccentPurple,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
