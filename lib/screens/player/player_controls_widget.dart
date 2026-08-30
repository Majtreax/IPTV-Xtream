import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_xtream/app/theme.dart';

// BOTTOM PLAYER CONTROLS BAR WITH TRANSPORT BUTTONS AND PROGRESS
class PlayerControls extends StatefulWidget {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final VoidCallback onRewind;
  final VoidCallback onForward;
  final VoidCallback onAudioTrack;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onChannelOverlay;
  final VoidCallback onVolumeTap;
  final VoidCallback? onStop;
  final VoidCallback? onSubtitleTap;
  final VoidCallback? onRefresh;
  final bool isVolumeActive;
  final bool isSubtitleActive;

  final String contentType;
  final bool hasAudioTracks;
  final bool hasSubtitles;
  final FocusNode? listButtonFocusNode;
  final FocusNode? playButtonFocusNode;
  final ValueChanged<bool>? onSeekHoldingChanged;

  const PlayerControls({
    super.key,
    required this.contentType,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onRewind,
    required this.onForward,
    required this.onAudioTrack,
    required this.onSeek,
    required this.onChannelOverlay,
    required this.onVolumeTap,
    this.onStop,
    this.onSubtitleTap,
    this.onRefresh,
    this.isVolumeActive = false,
    this.isSubtitleActive = false,
    this.hasAudioTracks = false,
    this.hasSubtitles = false,
    this.listButtonFocusNode,
    this.playButtonFocusNode,
    this.onSeekHoldingChanged,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  int? _accumulatedSeekSeconds;
  bool _isRewinding = false;

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.duration.inMilliseconds > 0
        ? (widget.position.inMilliseconds / widget.duration.inMilliseconds)
              .clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.fromLTRB(48, 16, 48, 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
              Colors.black.withValues(alpha: 0.85),
            ],
          ),
        ),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.contentType != 'live') ...[
                Row(
                  children: [
                    Text(
                      _formatDuration(widget.position),
                      style: const TextStyle(
                        fontSize: 13,
                        color: kTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) {
                              if (widget.duration.inMilliseconds > 0) {
                                final fraction = (details.localPosition.dx /
                                        constraints.maxWidth)
                                    .clamp(0.0, 1.0);
                                widget.onSeek(
                                  Duration(
                                    milliseconds:
                                        (fraction *
                                                widget
                                                    .duration.inMilliseconds)
                                            .round(),
                                  ),
                                );
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 5,
                                backgroundColor: kTextDisabled.withValues(
                                  alpha: 0.25,
                                ),
                                color: kAccentPurple,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatDuration(widget.duration),
                      style: const TextStyle(
                        fontSize: 13,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.contentType == 'live' ||
                      widget.contentType == 'series') ...[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 22),
                        ControlsButton(
                          focusNode: widget.listButtonFocusNode,
                          icon: Icons.format_list_bulleted_rounded,
                          onPressed: widget.onChannelOverlay,
                          autofocus:
                              widget.contentType == 'live' ||
                              widget.contentType == 'series',
                        ),
                      ],
                    ),
                    const Spacer(),
                  ] else ...[
                    const Spacer(),
                  ],

                  if (widget.contentType != 'live') ...[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedOpacity(
                          opacity: (_accumulatedSeekSeconds != null && _isRewinding) ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: Text(
                            '-${_accumulatedSeekSeconds ?? 10}s',
                            style: const TextStyle(
                              color: kAccentPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ControlsButton(
                          icon: Icons.replay_10_rounded,
                          onPressed: widget.onRewind,
                          onLongPressStart: () {
                            widget.onSeekHoldingChanged?.call(true);
                            setState(() {
                              _accumulatedSeekSeconds = 10;
                              _isRewinding = true;
                            });
                          },
                          onLongPressUpdate: (seconds) {
                            setState(() {
                              _accumulatedSeekSeconds = seconds;
                            });
                          },
                          onLongPressEnd: (seconds) {
                            widget.onSeekHoldingChanged?.call(false);
                            setState(() {
                              _accumulatedSeekSeconds = null;
                            });
                            widget.onSeek(
                              widget.position - Duration(seconds: seconds),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                  ],
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 22),
                      ControlsButton(
                        focusNode: widget.playButtonFocusNode,
                        icon: widget.contentType == 'live'
                            ? Icons.refresh_rounded
                            : (widget.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                        onPressed: widget.contentType == 'live'
                            ? (widget.onRefresh ?? widget.onPlayPause)
                            : widget.onPlayPause,
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 22),
                      ControlsButton(
                        icon: Icons.stop_rounded,
                        onPressed: widget.onStop ?? () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  if (widget.contentType != 'live') ...[
                    const SizedBox(width: 24),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedOpacity(
                          opacity: (_accumulatedSeekSeconds != null && !_isRewinding) ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: Text(
                            '+${_accumulatedSeekSeconds ?? 10}s',
                            style: const TextStyle(
                              color: kAccentPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ControlsButton(
                          icon: Icons.forward_10_rounded,
                          onPressed: widget.onForward,
                          onLongPressStart: () {
                            widget.onSeekHoldingChanged?.call(true);
                            setState(() {
                              _accumulatedSeekSeconds = 10;
                              _isRewinding = false;
                            });
                          },
                          onLongPressUpdate: (seconds) {
                            setState(() {
                              _accumulatedSeekSeconds = seconds;
                            });
                          },
                          onLongPressEnd: (seconds) {
                            widget.onSeekHoldingChanged?.call(false);
                            setState(() {
                              _accumulatedSeekSeconds = null;
                            });
                            widget.onSeek(
                              widget.position + Duration(seconds: seconds),
                            );
                          },
                        ),
                      ],
                    ),
                  ],

                  const Spacer(),

                  if (widget.contentType == 'live') ...[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 22),
                        ControlsButton(
                          icon: Icons.volume_up_rounded,
                          onPressed: widget.onVolumeTap,
                          forceActive: widget.isVolumeActive,
                        ),
                      ],
                    ),
                  ] else ...[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 22),
                        ControlsButton(
                          icon: Icons.volume_up_rounded,
                          onPressed: widget.onVolumeTap,
                          forceActive: widget.isVolumeActive,
                        ),
                      ],
                    ),
                    if (widget.hasAudioTracks) ...[
                      const SizedBox(width: 24),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 22),
                          ControlsButton(
                            icon: Icons.graphic_eq_rounded,
                            onPressed: widget.onAudioTrack,
                          ),
                        ],
                      ),
                    ],
                    if (widget.hasSubtitles) ...[
                      const SizedBox(width: 24),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 22),
                          ControlsButton(
                            icon: Icons.subtitles_rounded,
                            onPressed: widget.onSubtitleTap ?? () {},
                            forceActive: widget.isSubtitleActive,
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ControlsButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double buttonSize;
  final bool autofocus;
  final bool forceActive;
  final FocusNode? focusNode;
  final VoidCallback? onLongPressStart;
  final ValueChanged<int>? onLongPressUpdate;
  final ValueChanged<int>? onLongPressEnd;

  const ControlsButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 32,
    this.buttonSize = 52,
    this.autofocus = false,
    this.forceActive = false,
    this.focusNode,
    this.onLongPressStart,
    this.onLongPressUpdate,
    this.onLongPressEnd,
  });

  @override
  State<ControlsButton> createState() => _ControlsButtonState();
}

class _ControlsButtonState extends State<ControlsButton> {
  bool _isFocused = false;
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ??
      (_internalFocusNode ??= FocusNode(
        debugLabel: 'ControlsButton_${widget.icon.codePoint}',
      ));
  Timer? _holdTimer;
  int _accumulatedSeconds = 0;
  bool _isHolding = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _effectiveFocusNode.requestFocus();
        widget.onPressed();
      },
      onLongPressStart: (_) {
        _effectiveFocusNode.requestFocus();
        if (widget.onLongPressStart != null && !_isHolding) {
          _isHolding = true;
          _accumulatedSeconds = 10;
          widget.onLongPressStart?.call();
          _holdTimer?.cancel();
          _holdTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
            int step = 10;
            if (_accumulatedSeconds >= 100) {
              step = 50;
            } else if (_accumulatedSeconds >= 60) {
              step = 20;
            } else if (_accumulatedSeconds >= 30) {
              step = 15;
            }
            _accumulatedSeconds += step;
            widget.onLongPressUpdate?.call(_accumulatedSeconds);
          });
        }
      },
      onLongPressEnd: (_) {
        if (_isHolding) {
          _holdTimer?.cancel();
          _isHolding = false;
          if (_accumulatedSeconds > 10) {
            widget.onLongPressEnd?.call(_accumulatedSeconds);
          } else {
            widget.onPressed();
          }
          _accumulatedSeconds = 0;
        }
      },
      child: Focus(
        focusNode: _effectiveFocusNode,
        autofocus: widget.autofocus,
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            _holdTimer?.cancel();
            _isHolding = false;
            _accumulatedSeconds = 0;
          }
          if (mounted) setState(() => _isFocused = hasFocus);
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA) {
              if (widget.onLongPressStart != null && !_isHolding) {
                _isHolding = true;
                _accumulatedSeconds = 10;
                widget.onLongPressStart?.call();
                _holdTimer?.cancel();
                _holdTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
                  int step = 10;
                  if (_accumulatedSeconds >= 100) {
                    step = 50;
                  } else if (_accumulatedSeconds >= 60) {
                    step = 20;
                  } else if (_accumulatedSeconds >= 30) {
                    step = 15;
                  }
                  _accumulatedSeconds += step;
                  widget.onLongPressUpdate?.call(_accumulatedSeconds);
                });
              } else if (widget.onLongPressStart == null) {
                widget.onPressed();
              }
              return KeyEventResult.handled;
            }
          } else if (event is KeyUpEvent) {
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA) {
              if (_isHolding) {
                _holdTimer?.cancel();
                _isHolding = false;
                if (_accumulatedSeconds > 10) {
                  widget.onLongPressEnd?.call(_accumulatedSeconds);
                } else {
                  widget.onPressed();
                }
                _accumulatedSeconds = 0;
              }
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isFocused = true),
          onExit: (_) => setState(() => _isFocused = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.buttonSize,
            height: widget.buttonSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_isFocused || widget.forceActive)
                  ? kAccentPurple.withValues(alpha: 0.15)
                  : Colors.transparent,
              border: Border.all(
                color: (_isFocused || widget.forceActive)
                    ? kAccentPurple.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
              boxShadow: (_isFocused || widget.forceActive)
                  ? [
                      BoxShadow(
                        color: kAccentPurple.withValues(alpha: 0.2),
                        blurRadius: 12,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              widget.icon,
              color: (_isFocused || widget.forceActive)
                  ? kAccentPurple
                  : kTextPrimary,
              size: widget.size,
            ),
          ),
        ),
      ),
    );
  }
}
