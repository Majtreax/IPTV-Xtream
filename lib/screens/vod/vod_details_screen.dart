import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_xtream/providers/vod_provider.dart';
import 'package:iptv_xtream/providers/last_played_provider.dart';
import 'package:flutter/services.dart';
import 'package:iptv_xtream/app/theme.dart';
import 'package:iptv_xtream/models/vod_model.dart';
import 'package:iptv_xtream/widgets/app_button.dart';
import 'package:iptv_xtream/widgets/loading_indicator.dart';

// AN OVERLAY DETAIL SHEET FOR VOD ITEMS (MOVIES/SERIES)
class VodDetails extends ConsumerStatefulWidget {
  final VodItem item;
  final bool isOpenedFromPlayer;

  const VodDetails({
    super.key,
    required this.item,
    this.isOpenedFromPlayer = false,
  });

  @override
  ConsumerState<VodDetails> createState() => _VodDetailsState();
}

class _VodDetailsState extends ConsumerState<VodDetails>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  int _selectedSeason = 0;
  bool _isLoadingInfo = false;
  late VodItem _displayItem;

  List<FocusNode> _seasonFocusNodes = [];

  void _initSeasonFocusNodes(int count) {
    for (var node in _seasonFocusNodes) {
      node.dispose();
    }
    _seasonFocusNodes = List.generate(count, (index) => FocusNode(debugLabel: 'SeasonFocusNode_$index'));
  }

  StateNotifierProvider<VodNotifier, VodState> get _provider =>
      widget.item.streamType == 'series' ? seriesProvider : moviesProvider;

  @override
  void initState() {
    super.initState();
    _displayItem = widget.item;
    if (_displayItem.seasons != null) {
      _initSeasonFocusNodes(_displayItem.seasons!.length);
    }
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();

    final isSeries = widget.item.streamType == 'series';
    final needsFetch = isSeries
        ? (widget.item.seasons == null || widget.item.seasons!.isEmpty)
        : (widget.item.plot == null || widget.item.plot!.isEmpty);

    if (needsFetch) {
      _isLoadingInfo = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (isSeries) {
          await ref
              .read(_provider.notifier)
              .loadSeriesInfo(widget.item.streamId.toString());
        } else {
          await ref
              .read(_provider.notifier)
              .loadMovieInfo(widget.item.streamId.toString());
        }

        if (mounted) {
          final updated = ref.read(_provider).selectedItem;
          setState(() {
            if (updated != null) {
              _displayItem = updated;
              if (_displayItem.seasons != null) {
                _initSeasonFocusNodes(_displayItem.seasons!.length);
              }
            }
            _isLoadingInfo = false;
          });
          if (_displayItem.seasons != null && _displayItem.seasons!.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _seasonFocusNodes.isNotEmpty) {
                _seasonFocusNodes[_selectedSeason.clamp(0, _seasonFocusNodes.length - 1)].requestFocus();
              }
            });
          }
        }
      });
    } else if (isSeries && _seasonFocusNodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _seasonFocusNodes.isNotEmpty) {
          _seasonFocusNodes[_selectedSeason.clamp(0, _seasonFocusNodes.length - 1)].requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    for (var node in _seasonFocusNodes) {
      node.dispose();
    }
    _animController.dispose();
    super.dispose();
  }

  void _close() {
    _animController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  bool get _isSeries => widget.item.streamType == 'series';

  void _playEpisode(Episode ep, int seasonNumber) {
    final url = ref
        .read(_provider.notifier)
        .getEpisodeStreamUrl(ep.id, extension: ep.containerExtension ?? 'mp4');
    if (widget.isOpenedFromPlayer) {
      Navigator.of(context).pop({
        'episode': ep,
        'seasonNumber': seasonNumber,
        'streamUrl': url,
      });
    } else {
      final lastSeries = ref.read(lastSeriesProvider);
      final startPos = (lastSeries?.item.streamId == widget.item.streamId &&
              lastSeries?.episode?.id == ep.id)
          ? lastSeries?.positionMs
          : null;
      final nav = Navigator.of(context);
      nav.pop();
      nav.pushNamed(
        '/player',
        arguments: {
          'type': 'series',
          'movieItem': widget.item,
          'episode': ep,
          'seasonNumber': seasonNumber,
          'streamUrl': url,
          'startPositionMs': startPos,
        },
      );
    }
  }

  void _playMovie() {
    final lastMovie = ref.read(lastMovieProvider);
    final startPos = (lastMovie?.item.streamId == widget.item.streamId)
        ? lastMovie?.positionMs
        : null;
    final nav = Navigator.of(context);
    final url = ref.read(_provider.notifier).getMovieStreamUrl(widget.item);
    nav.pop();
    nav.pushNamed(
      '/player',
      arguments: {
        'type': 'movie',
        'movieItem': widget.item,
        'streamUrl': url,
        'startPositionMs': startPos,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.guide ||
                event.logicalKey == LogicalKeyboardKey.info ||
                event.logicalKey == LogicalKeyboardKey.contextMenu ||
                event.logicalKey == LogicalKeyboardKey.tvDataService)) {
          _close();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {},
        child: SlideTransition(
          position: _slideAnimation,
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.85,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        if (_displayItem.coverUrl != null &&
                            _displayItem.coverUrl!.isNotEmpty)
                          Positioned.fill(
                            child: Image.network(
                              _displayItem.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: kSurfaceCard.withValues(alpha: 0.97),
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                            child: Container(
                              decoration: BoxDecoration(
                                color: kDeepBackground.withValues(alpha: 0.8),
                                border: Border.all(
                                  color: kAccentPurple.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),

                        FocusTraversalGroup(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: SizedBox(
                                        width: 200,
                                        height: 300,
                                        child:
                                            _displayItem.coverUrl != null &&
                                                _displayItem
                                                    .coverUrl!
                                                    .isNotEmpty
                                            ? Image.network(
                                                _displayItem.coverUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    Container(
                                                      color: kDeepBackground,
                                                      child: const Icon(
                                                        Icons.movie_outlined,
                                                        size: 80,
                                                        color: kTextDisabled,
                                                      ),
                                                    ),
                                              )
                                            : Container(
                                                color: kDeepBackground,
                                                child: const Icon(
                                                  Icons.movie_outlined,
                                                  size: 80,
                                                  color: kTextDisabled,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 48),

                                    Expanded(
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minHeight: 300,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              _displayItem.name,
                                              style: const TextStyle(
                                                fontSize: 36,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                if (_displayItem.rating !=
                                                        null &&
                                                    _displayItem.rating! >
                                                        0) ...[
                                                  const Icon(
                                                    Icons.star_rounded,
                                                    size: 20,
                                                    color: kAccentPurple,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _displayItem.rating!
                                                        .toStringAsFixed(1),
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: kAccentPurple,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 20),
                                                ],
                                                if (_displayItem.releaseDate !=
                                                    null) ...[
                                                  Text(
                                                    _displayItem.releaseDate!,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: kTextSecondary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 20),
                                                ],
                                                if (_displayItem.genre != null)
                                                  Flexible(
                                                    child: Text(
                                                      _displayItem.genre!,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: kTextSecondary,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 24),

                                            if (_displayItem.plot != null &&
                                                _displayItem
                                                    .plot!
                                                    .isNotEmpty) ...[
                                              Text(
                                                _displayItem.plot!,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  color: kTextSecondary,
                                                  height: 1.5,
                                                ),
                                                maxLines: 5,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 12),
                                            ],

                                            if (_displayItem.director != null &&
                                                _displayItem
                                                    .director!
                                                    .isNotEmpty) ...[
                                              Text(
                                                'Director: ${_displayItem.director}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: kTextDisabled,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                            ],
                                            if (_displayItem.cast != null &&
                                                _displayItem
                                                    .cast!
                                                    .isNotEmpty) ...[
                                              Text(
                                                'Cast: ${_displayItem.cast}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: kTextDisabled,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],

                                            const SizedBox(height: 32),

                                            if (_isLoadingInfo) ...[
                                              const SizedBox(height: 40),
                                              const Center(
                                                child: LoadingIndicator(),
                                              ),
                                            ] else if (!_isSeries) ...[
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Focus(
                                                  onKeyEvent: (node, event) {
                                                    if (event is KeyDownEvent) {
                                                      if (event.logicalKey ==
                                                              LogicalKeyboardKey
                                                                  .arrowUp ||
                                                          event.logicalKey ==
                                                              LogicalKeyboardKey
                                                                  .arrowDown ||
                                                          event.logicalKey ==
                                                              LogicalKeyboardKey
                                                                  .arrowLeft ||
                                                          event.logicalKey ==
                                                              LogicalKeyboardKey
                                                                  .arrowRight) {
                                                        return KeyEventResult
                                                            .handled;
                                                      }
                                                    }
                                                    return KeyEventResult
                                                        .ignored;
                                                  },
                                                  child: AppButton(
                                                    label: 'Play Movie',
                                                    icon: Icons
                                                        .play_arrow_rounded,
                                                    primary: true,
                                                    isVertical: false,
                                                    fontSize: 18,
                                                    iconSize: 32,
                                                    autofocus: true,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 40,
                                                          vertical: 20,
                                                        ),
                                                    onPressed: _playMovie,
                                                  ),
                                                ),
                                              ),
                                            ] else if (_isSeries) ...[
                                              const SizedBox(height: 16),
                                              _buildSeasonSelector(),
                                              const SizedBox(height: 16),
                                              _buildEpisodeList(),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeasonSelector() {
    final seasons = _displayItem.seasons!;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: seasons.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final isSelected = index == _selectedSeason;
          return _SeasonButton(
            key: ValueKey('season_${seasons[index].seasonNumber}'),
            focusNode: index < _seasonFocusNodes.length ? _seasonFocusNodes[index] : null,
            label: 'Season ${seasons[index].seasonNumber}',
            isSelected: isSelected,
            autofocus: index == _selectedSeason,
            onTap: () {
              if (index < _seasonFocusNodes.length) {
                _seasonFocusNodes[index].requestFocus();
              }
              setState(() => _selectedSeason = index);
            },
            onMoveLeft: index == 0
                ? () {}
                : () {
                    final prevIndex = index - 1;
                    if (prevIndex < _seasonFocusNodes.length) {
                      _seasonFocusNodes[prevIndex].requestFocus();
                      setState(() => _selectedSeason = prevIndex);
                    }
                  },
            onMoveRight: index == seasons.length - 1
                ? () {}
                : () {
                    final nextIndex = index + 1;
                    if (nextIndex < _seasonFocusNodes.length) {
                      _seasonFocusNodes[nextIndex].requestFocus();
                      setState(() => _selectedSeason = nextIndex);
                    }
                  },
          );
        },
      ),
    );
  }

  Widget _buildEpisodeList() {
    final seasons = _displayItem.seasons!;
    if (_selectedSeason >= seasons.length) return const SizedBox.shrink();
    final episodes = seasons[_selectedSeason].episodes;
    final seasonNumber = seasons[_selectedSeason].seasonNumber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: episodes.asMap().entries.map((entry) {
        final index = entry.key;
        final ep = entry.value;
        return _EpisodeRow(
          key: ValueKey('episode_${ep.id}'),
          episode: ep,
          seasonNumber: seasonNumber,
          onTap: () => _playEpisode(ep, seasonNumber),
          onMoveLeft: () {},
          onMoveRight: () {},
          onMoveDown: index == episodes.length - 1 ? () {} : null,
          onMoveUp: index == 0
              ? () {
                  if (_selectedSeason < _seasonFocusNodes.length) {
                    _seasonFocusNodes[_selectedSeason].requestFocus();
                  } else {
                    FocusScope.of(context).focusInDirection(TraversalDirection.up);
                  }
                }
              : null,
        );
      }).toList(),
    );
  }
}

class _SeasonButton extends StatefulWidget {
  final FocusNode? focusNode;
  final String label;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onTap;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;

  const _SeasonButton({
    super.key,
    this.focusNode,
    required this.label,
    required this.isSelected,
    required this.autofocus,
    required this.onTap,
    this.onMoveLeft,
    this.onMoveRight,
  });

  @override
  State<_SeasonButton> createState() => _SeasonButtonState();
}

class _SeasonButtonState extends State<_SeasonButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.focusNode?.requestFocus();
        widget.onTap();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Focus(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          onFocusChange: (focused) {},
          onKeyEvent: (node, event) {
            if (event is! KeyUpEvent) {
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                widget.onTap();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                if (widget.onMoveRight != null) {
                  widget.onMoveRight!();
                  return KeyEventResult.handled;
                }
                node.nextFocus();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                if (widget.onMoveLeft != null) {
                  widget.onMoveLeft!();
                  return KeyEventResult.handled;
                }
                node.previousFocus();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                FocusScope.of(context).focusInDirection(TraversalDirection.down);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Builder(
            builder: (ctx) {
              final focused = Focus.of(ctx).hasFocus;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: buildSeasonButtonDecoration(
                  isFocused: focused,
                  isSelected: widget.isSelected,
                  isHovered: _isHovered,
                  radius: kSmallRadius,
                ),
                child: Text(
                  widget.label,
                  style: kTextStyleBody.copyWith(
                    fontSize: 16,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: widget.isSelected
                        ? kAccentPurple
                        : ((focused || _isHovered)
                            ? Colors.white
                            : kTextSecondary),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatefulWidget {
  final Episode episode;
  final int seasonNumber;
  final VoidCallback onTap;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _EpisodeRow({
    super.key,
    required this.episode,
    required this.seasonNumber,
    required this.onTap,
    this.onMoveLeft,
    this.onMoveRight,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  State<_EpisodeRow> createState() => _EpisodeRowState();
}

class _EpisodeRowState extends State<_EpisodeRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Focus(
          onFocusChange: (_) {},
          onKeyEvent: (node, event) {
            if (event is! KeyUpEvent) {
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                widget.onTap();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                if (widget.onMoveDown != null) {
                  widget.onMoveDown!();
                  return KeyEventResult.handled;
                }
                node.nextFocus();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                if (widget.onMoveUp != null) {
                  widget.onMoveUp!();
                  return KeyEventResult.handled;
                }
                FocusScope.of(context).focusInDirection(TraversalDirection.up);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                widget.onMoveLeft?.call();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                widget.onMoveRight?.call();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Builder(
            builder: (ctx) {
              final focused = Focus.of(ctx).hasFocus;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: (focused || _isHovered)
                      ? kAccentPurple.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(kSmallRadius),
                  border: Border.all(
                    color: (focused || _isHovered) ? kAccentPurple : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: (focused || _isHovered)
                            ? kAccentPurple.withValues(alpha: 0.2)
                            : kDeepBackground,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.episode.episodeNum}',
                          style: kTextStyleBody.copyWith(
                            fontWeight: FontWeight.w700,
                            color: (focused || _isHovered) ? kAccentPurple : kTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.play_circle_filled_rounded,
                      size: 28,
                      color: (focused || _isHovered) ? Colors.white : kAccentPurple,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.episode.title,
                        style: kTextStyleBody.copyWith(
                          fontSize: 15,
                          color: (focused || _isHovered) ? kTextPrimary : kTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.episode.durationSeconds != null)
                      Text(
                        '${widget.episode.durationSeconds! ~/ 60}m',
                        style: kTextStyleCaption.copyWith(
                          fontSize: 13,
                          color: kTextDisabled,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
