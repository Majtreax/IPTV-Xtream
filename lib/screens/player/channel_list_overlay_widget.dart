import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_xtream/app/theme.dart';
import 'package:iptv_xtream/models/channel_model.dart';
import 'package:iptv_xtream/models/category_model.dart';
import 'package:iptv_xtream/providers/category_provider.dart';
import 'package:iptv_xtream/providers/channel_provider.dart';
import 'package:iptv_xtream/providers/last_played_provider.dart';
import 'package:iptv_xtream/widgets/loading_indicator.dart';
import 'package:iptv_xtream/providers/settings_provider.dart';

// IN-PLAYER CHANNEL LIST OVERLAY WITH MODERN PURPLE GLASSMORPHISM
// CATEGORIES ON THE LEFT, AND CHANNELS ON THE RIGHT
class ChannelOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final Function(Channel) onChannelSelected;
  final Channel? currentChannel;

  const ChannelOverlay({
    super.key,
    required this.onClose,
    required this.onChannelSelected,
    this.currentChannel,
  });

  @override
  ConsumerState<ChannelOverlay> createState() => _ChannelListOverlayState();
}

class _ChannelListOverlayState extends ConsumerState<ChannelOverlay> {
  List<Category> _categories = [];
  List<Channel> _allLiveChannels = [];
  List<Channel> _groupChannels = [];

  bool _isLoading = true;
  String _selectedCategoryId = '';

  late final ScrollController _categoryScrollController;
  late final ScrollController _channelScrollController;
  final Map<int, FocusNode> _categoryFocusNodes = {};
  final Map<int, FocusNode> _channelFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _categoryScrollController = ScrollController();
    _channelScrollController = ScrollController();
    _loadData();
  }

  @override
  void dispose() {
    _categoryScrollController.dispose();
    _channelScrollController.dispose();
    for (final node in _categoryFocusNodes.values) {
      node.dispose();
    }
    for (final node in _channelFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  bool _isSameChannel(Channel? a, Channel? b) {
    if (a == null || b == null) return false;
    if (a.streamId != 0 && b.streamId != 0 && a.streamId == b.streamId) {
      return true;
    }
    if (a.streamUrl.isNotEmpty &&
        b.streamUrl.isNotEmpty &&
        a.streamUrl == b.streamUrl) {
      return true;
    }
    return a.name.isNotEmpty &&
        a.name == b.name &&
        a.groupTitle == b.groupTitle;
  }

  Future<void> _loadData() async {
    var liveCats = ref.read(liveCategoriesProvider);
    if (liveCats.isEmpty) {
      final repo = ref.read(channelRepositoryProvider);
      final fetchedCats = await repo.getCategories();
      liveCats = fetchedCats
          .where((c) => c.type == 'live' || c.type.isEmpty)
          .toList();
    }

    var liveChannels = ref.read(channelProvider).channels;
    if (liveChannels.isEmpty) {
      final repo = ref.read(channelRepositoryProvider);
      final allChannels = await repo.getChannels();
      liveChannels =
          allChannels.where((c) => c.streamType == 'live').toList();
    }

    _allLiveChannels = liveChannels;
    _categories = liveCats;

    if (_categories.isEmpty && _allLiveChannels.isNotEmpty) {
      _categories = [
        const Category(id: 'all', name: 'ALL CHANNELS', type: 'live'),
      ];
    }

    final currentCh = widget.currentChannel;
    if (currentCh != null) {
      if (currentCh.categoryId.isNotEmpty &&
          _categories.any((c) => c.id == currentCh.categoryId)) {
        _selectedCategoryId = currentCh.categoryId;
      } else if (currentCh.groupTitle.isNotEmpty) {
        final matchingCat = _categories
            .where(
              (c) =>
                  c.name.toLowerCase() == currentCh.groupTitle.toLowerCase(),
            )
            .firstOrNull;
        if (matchingCat != null) {
          _selectedCategoryId = matchingCat.id;
        } else {
          _selectedCategoryId =
              _categories.isNotEmpty ? _categories.first.id : 'all';
        }
      } else {
        _selectedCategoryId =
            _categories.isNotEmpty ? _categories.first.id : 'all';
      }
    } else {
      _selectedCategoryId =
          _categories.isNotEmpty ? _categories.first.id : 'all';
    }

    _updateGroupChannels();

    if (mounted) {
      setState(() => _isLoading = false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final catIdx =
            _categories.indexWhere((c) => c.id == _selectedCategoryId);
        if (catIdx > 0 && _categoryScrollController.hasClients) {
          final maxScroll =
              _categoryScrollController.position.maxScrollExtent;
          final target = (catIdx * 48.0 - 120.0).clamp(0.0, maxScroll);
          _categoryScrollController.jumpTo(target);
        }

        if (currentCh != null) {
          final chIdx = _groupChannels.indexWhere(
            (c) => _isSameChannel(c, currentCh),
          );
          if (chIdx > 0 && _channelScrollController.hasClients) {
            final maxScroll =
                _channelScrollController.position.maxScrollExtent;
            final target = (chIdx * 60.0 - 120.0).clamp(0.0, maxScroll);
            _channelScrollController.jumpTo(target);
          }
        }
      });
    }
  }

  void _updateGroupChannels() {
    final cat = _categories
        .where((c) => c.id == _selectedCategoryId)
        .firstOrNull;
    if (cat == null) {
      _groupChannels = [];
      return;
    }

    if (cat.id == 'all') {
      _groupChannels = _allLiveChannels;
    } else {
      _groupChannels = _allLiveChannels.where((c) {
        if (c.categoryId.isNotEmpty && cat.id.isNotEmpty && cat.id != 'all') {
          return c.categoryId == cat.id;
        }
        return c.groupTitle.toLowerCase() == cat.name.toLowerCase();
      }).toList();
    }
  }

  void _selectCategory(String catId) {
    if (_selectedCategoryId == catId) return;
    for (final node in _channelFocusNodes.values) {
      node.dispose();
    }
    _channelFocusNodes.clear();
    setState(() {
      _selectedCategoryId = catId;
      _updateGroupChannels();
    });
    if (_channelScrollController.hasClients) {
      _channelScrollController.jumpTo(0.0);
    }
  }

  void _focusPlayingOrFirstChannel() {
    if (_groupChannels.isEmpty) return;
    int idx = -1;
    final currentCh = widget.currentChannel;
    if (currentCh != null) {
      idx =
          _groupChannels.indexWhere((c) => _isSameChannel(c, currentCh));
    }
    if (idx == -1) idx = 0;

    final node = _channelFocusNodes[idx];
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
    }
  }

  void _focusCategoryOfSelectedChannel() {
    final idx = _categories.indexWhere((c) => c.id == _selectedCategoryId);
    if (idx != -1) {
      final node = _categoryFocusNodes[idx];
      if (node != null && node.canRequestFocus) {
        node.requestFocus();
      }
    }
  }

  void _handleChannelSelect(Channel channel) {
    final isAlreadyPlaying = _isSameChannel(widget.currentChannel, channel);

    if (isAlreadyPlaying) {
      widget.onClose();
    } else {
      ref.read(lastPlayedProvider.notifier).setLastChannel(channel);
      widget.onChannelSelected(channel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSizeLevel = ref.watch(settingsProvider).fontSizeLevel;
    final double overlayScale;
    switch (fontSizeLevel) {
      case 2:
        overlayScale = 1.15;
        break;
      case 3:
        overlayScale = 1.25;
        break;
      case 1:
      default:
        overlayScale = 1.0;
        break;
    }

    final categoryColWidth = 280.0 * overlayScale;
    final drawerWidth = 590.0 * overlayScale;

    final activeCat = _categories
        .where((c) => c.id == _selectedCategoryId)
        .firstOrNull;
    final channelsHeaderTitle =
        (activeCat != null && activeCat.name.isNotEmpty)
            ? activeCat.name.toUpperCase()
            : 'CHANNELS';

    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyUpEvent &&
            (event.logicalKey == LogicalKeyboardKey.guide ||
                event.logicalKey == LogicalKeyboardKey.info ||
                event.logicalKey == LogicalKeyboardKey.contextMenu ||
                event.logicalKey == LogicalKeyboardKey.tvDataService ||
                event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.escape)) {
          widget.onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: drawerWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kDeepBackground.withValues(alpha: 0.90),
                  kSurfaceCard.withValues(alpha: 0.80),
                ],
              ),
              border: Border(
                right: BorderSide(
                  color: kAccentPurple.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: kAccentPurple.withValues(alpha: 0.12),
                  blurRadius: 32,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: categoryColWidth - 16,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: kAccentPurple.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: kAccentPurple.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: kAccentPurple.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'CATEGORIES',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: kAccentPurple.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: kAccentPurple.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: kAccentPurple.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Text(
                                channelsHeaderTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: kAccentPurple.withValues(alpha: 0.2),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: LoadingIndicator())
                        : ScrollConfiguration(
                            behavior:
                                ScrollConfiguration.of(context).copyWith(
                              scrollbars: false,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: categoryColWidth,
                                  child: FocusScope(
                                    child: ListView.builder(
                                      controller: _categoryScrollController,
                                      padding: const EdgeInsets.only(
                                        left: 12,
                                        right: 8,
                                        top: 8,
                                        bottom: 8,
                                      ),
                                      itemCount: _categories.length,
                                      itemBuilder: (context, index) {
                                        final cat = _categories[index];
                                        final node =
                                            _categoryFocusNodes.putIfAbsent(
                                          index,
                                          () => FocusNode(
                                            debugLabel: 'Category-$index',
                                          ),
                                        );
                                        final isSelected =
                                            cat.id == _selectedCategoryId;
                                        return _CategoryRow(
                                          key: ValueKey(cat.id),
                                          category: cat,
                                          isSelected: isSelected,
                                          autofocus: isSelected,
                                          overlayScale: overlayScale,
                                          focusNode: node,
                                          onTap: () {
                                            _selectCategory(cat.id);
                                          },
                                          onKeyEvent: (node, event) {
                                            if (event is KeyDownEvent) {
                                              if (event.logicalKey ==
                                                  LogicalKeyboardKey
                                                      .arrowDown) {
                                                FocusScope.of(context)
                                                    .focusInDirection(
                                                      TraversalDirection.down,
                                                    );
                                                return KeyEventResult.handled;
                                              }
                                              if (event.logicalKey ==
                                                  LogicalKeyboardKey
                                                      .arrowUp) {
                                                FocusScope.of(context)
                                                    .focusInDirection(
                                                      TraversalDirection.up,
                                                    );
                                                return KeyEventResult.handled;
                                              }
                                              if (event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .arrowRight ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .select ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .enter ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .gameButtonA) {
                                                _focusPlayingOrFirstChannel();
                                                return KeyEventResult.handled;
                                              }
                                              if (event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .arrowLeft ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .guide ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .info ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .contextMenu ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .tvDataService ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .goBack ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .escape) {
                                                widget.onClose();
                                                return KeyEventResult.handled;
                                              }
                                            }
                                            return KeyEventResult.ignored;
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  color: kAccentPurple.withValues(alpha: 0.15),
                                ),
                                Expanded(
                                  child: FocusScope(
                                    child: ListView.builder(
                                      key: ValueKey(_selectedCategoryId),
                                      controller: _channelScrollController,
                                      padding: const EdgeInsets.only(
                                        left: 8,
                                        right: 12,
                                        top: 8,
                                        bottom: 8,
                                      ),
                                      itemCount: _groupChannels.length,
                                      itemBuilder: (context, index) {
                                        final channel =
                                            _groupChannels[index];
                                        final node =
                                            _channelFocusNodes.putIfAbsent(
                                          index,
                                          () => FocusNode(
                                            debugLabel: 'Channel-$index',
                                          ),
                                        );
                                        final isCurrentlyPlaying =
                                            _isSameChannel(
                                          widget.currentChannel,
                                          channel,
                                        );
                                        final shouldAutofocus =
                                            isCurrentlyPlaying ||
                                                (widget.currentChannel ==
                                                        null &&
                                                    index == 0);
                                        return _ChannelRow(
                                          key: ValueKey(
                                            '${channel.streamId}_$index',
                                          ),
                                          channel: channel,
                                          isPlaying: isCurrentlyPlaying,
                                          autofocus: shouldAutofocus,
                                          overlayScale: overlayScale,
                                          focusNode: node,
                                          onTap: () =>
                                              _handleChannelSelect(channel),
                                          onKeyEvent: (node, event) {
                                            if (event is KeyDownEvent) {
                                              if (event.logicalKey ==
                                                  LogicalKeyboardKey
                                                      .arrowDown) {
                                                FocusScope.of(context)
                                                    .focusInDirection(
                                                      TraversalDirection.down,
                                                    );
                                                return KeyEventResult.handled;
                                              }
                                              if (event.logicalKey ==
                                                  LogicalKeyboardKey
                                                      .arrowUp) {
                                                FocusScope.of(context)
                                                    .focusInDirection(
                                                      TraversalDirection.up,
                                                    );
                                                return KeyEventResult.handled;
                                              }
                                              if (event.logicalKey ==
                                                  LogicalKeyboardKey
                                                      .select ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .enter ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .space ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .gameButtonA) {
                                                _handleChannelSelect(channel);
                                                return KeyEventResult.handled;
                                              }
                                              if (event.logicalKey ==
                                                  LogicalKeyboardKey
                                                      .arrowLeft) {
                                                _focusCategoryOfSelectedChannel();
                                                return KeyEventResult.handled;
                                              }
                                              if (event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .arrowRight ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .guide ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .info ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .contextMenu ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .tvDataService ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .goBack ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .escape) {
                                                widget.onClose();
                                                return KeyEventResult.handled;
                                              }
                                            }
                                            return KeyEventResult.ignored;
                                          },
                                        );
                                      },
                                    ),
                                  ),
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
    );
  }
}

class _CategoryRow extends StatefulWidget {
  final Category category;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback onKeyEvent;
  final double overlayScale;

  const _CategoryRow({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
    this.autofocus = false,
    this.focusNode,
    required this.onKeyEvent,
    this.overlayScale = 1.0,
  });

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ??
        FocusNode(debugLabel: 'Cat-${widget.category.id}');
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final isFocused = _isFocused;
    final isHovered = _isHovered && !isFocused;

    final bgColor = isFocused
        ? kAccentPurple.withValues(alpha: 0.38)
        : isSelected
            ? kAccentPurple.withValues(alpha: 0.22)
            : isHovered
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent;

    final borderColor = (isFocused || isSelected)
        ? kAccentPurple
        : isHovered
            ? kAccentPurple.withValues(alpha: 0.5)
            : Colors.transparent;

    final textColor = (isFocused || isSelected)
        ? Colors.white
        : (isHovered ? kTextPrimary : kTextSecondary);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _focusNode.requestFocus();
        widget.onTap();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Focus(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onFocusChange: (focused) {
            setState(() => _isFocused = focused);
            if (focused) {
              widget.onTap();
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
              );
            }
          },
          onKeyEvent: widget.onKeyEvent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: borderColor,
                width: (isFocused || isSelected) ? 1.5 : 1,
              ),
              boxShadow: (isFocused || isSelected)
                  ? [
                      BoxShadow(
                        color: kAccentPurple.withValues(
                          alpha: isFocused ? 0.4 : 0.2,
                        ),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                if (isSelected || isFocused)
                  Container(
                    width: 3.5,
                    height: 16,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: kAccentPurple,
                      borderRadius: BorderRadius.circular(1.5),
                      boxShadow: [
                        BoxShadow(
                          color: kAccentPurple.withValues(alpha: 0.8),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Text(
                    widget.category.name,
                    style: kTextStyleBody.copyWith(
                      fontSize: 14 * widget.overlayScale,
                      fontWeight: (isSelected || isFocused)
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected && !isFocused)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kAccentPurple,
                      boxShadow: [
                        BoxShadow(
                          color: kAccentPurple.withValues(alpha: 0.8),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelRow extends StatefulWidget {
  final Channel channel;
  final bool isPlaying;
  final bool autofocus;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback onKeyEvent;
  final double overlayScale;

  const _ChannelRow({
    super.key,
    required this.channel,
    required this.isPlaying,
    required this.onTap,
    this.autofocus = false,
    this.focusNode,
    required this.onKeyEvent,
    this.overlayScale = 1.0,
  });

  @override
  State<_ChannelRow> createState() => _ChannelRowState();
}

class _ChannelRowState extends State<_ChannelRow> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ??
        FocusNode(debugLabel: 'Ch-${widget.channel.streamId}');
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = widget.isPlaying;
    final isFocused = _isFocused;
    final isHovered = _isHovered && !isFocused;

    final bgColor = isFocused
        ? kAccentPurple.withValues(alpha: 0.35)
        : isPlaying
            ? kAccentPurple.withValues(alpha: 0.18)
            : isHovered
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent;

    final borderColor = isFocused
        ? kAccentPurple
        : isPlaying
            ? kAccentPurple.withValues(alpha: 0.65)
            : isHovered
                ? kAccentPurple.withValues(alpha: 0.4)
                : Colors.transparent;

    final textColor = isFocused
        ? Colors.white
        : isPlaying
            ? kAccentPurple
            : (isHovered ? kTextPrimary : kTextSecondary);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _focusNode.requestFocus();
        widget.onTap();
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onFocusChange: (focused) {
          setState(() => _isFocused = focused);
          if (focused) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.5,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
            );
          }
        },
        onKeyEvent: widget.onKeyEvent,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: borderColor,
                width: (isFocused || isPlaying) ? 1.5 : 1,
              ),
              boxShadow: (isFocused || isPlaying)
                  ? [
                      BoxShadow(
                        color: kAccentPurple.withValues(
                          alpha: isFocused ? 0.4 : 0.2,
                        ),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 38,
                    height: 38,
                    color: kSurfaceCard.withValues(alpha: 0.7),
                    child: widget.channel.logoUrl.isNotEmpty
                        ? Image.network(
                            widget.channel.logoUrl,
                            width: 38,
                            height: 38,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.tv,
                              color: kTextDisabled,
                              size: 20,
                            ),
                          )
                        : const Icon(Icons.tv,
                            color: kTextDisabled, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.channel.name,
                    style: kTextStyleBody.copyWith(
                      fontSize: 14.5 * widget.overlayScale,
                      fontWeight: (isPlaying || isFocused)
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isPlaying)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kAccentPurple,
                      boxShadow: [
                        BoxShadow(
                          color: kAccentPurple.withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 1.5,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
