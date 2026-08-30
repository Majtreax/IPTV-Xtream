import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_xtream/app/theme.dart';
import 'package:iptv_xtream/providers/settings_provider.dart';

class LastPlayedBanner extends ConsumerStatefulWidget {
  final String title;
  final String? subtitle;
  final String? progressText;
  final String? imageUrl;
  final String badgeText;
  final double? progressPercent;
  final VoidCallback onTap;

  const LastPlayedBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.progressText,
    this.imageUrl,
    this.badgeText = 'CONTINUE WATCHING',
    this.progressPercent,
    required this.onTap,
  });

  @override
  ConsumerState<LastPlayedBanner> createState() => _LastPlayedBannerState();
}

class _LastPlayedBannerState extends ConsumerState<LastPlayedBanner> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final textScale = ref.watch(fontSizeScaleProvider);
    final hasProgress =
        widget.progressPercent != null && widget.progressPercent! > 0.0;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                constraints: BoxConstraints(
                  minWidth: 740 * textScale,
                  maxWidth: 740 * textScale,
                ),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                decoration: _isFocused
                    ? buildGlassyPillDecoration(
                        radius: 14,
                        glowAlpha: 0.4,
                      ).copyWith(
                        border: Border.all(
                          color: kAccentPurple.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                      )
                    : buildGlassyPillDecoration(
                        radius: 14,
                        glowAlpha: 0.15,
                      ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isFocused
                                ? kAccentPurple
                                : Colors.white.withValues(alpha: 0.12),
                            boxShadow: _isFocused
                                ? [
                                    BoxShadow(
                                      color: kAccentPurple.withValues(alpha: 0.5),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        if (widget.imageUrl != null &&
                            widget.imageUrl!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.imageUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(),
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.title,
                                style: kTextStyleTitle.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  if (widget.subtitle != null &&
                                      widget.subtitle!.isNotEmpty) ...[
                                    Flexible(
                                      child: Text(
                                        widget.subtitle!,
                                        style: kTextStyleCaption.copyWith(
                                          fontSize: 12.5,
                                          color: kTextSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  if (widget.progressText != null &&
                                      widget.progressText!.isNotEmpty) ...[
                                    if (widget.subtitle != null &&
                                        widget.subtitle!.isNotEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        child: Text(
                                          '·',
                                          style: TextStyle(
                                            color: kTextDisabled,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    Flexible(
                                      flex: 0,
                                      child: Text(
                                        widget.progressText!,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: kAccentPurple,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isFocused
                                ? kAccentPurple.withValues(alpha: 0.25)
                                : kAccentPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isFocused
                                  ? kAccentPurple
                                  : kAccentPurple.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.badgeText.toUpperCase(),
                                style: kTextStyleCaption.copyWith(
                                  color: _isFocused
                                      ? Colors.white
                                      : kAccentPurple,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (hasProgress) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: widget.progressPercent!.clamp(0.01, 1.0),
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            kAccentPurple,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
