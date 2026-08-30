import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iptv_xtream/app/theme.dart';
import 'package:iptv_xtream/models/channel_model.dart';
import 'package:iptv_xtream/providers/channel_provider.dart';
import 'package:iptv_xtream/providers/tab_focus_provider.dart';
import 'package:iptv_xtream/widgets/tv_card.dart';

// A SINGLE CHANNEL ROW DISPLAYING LOGO, NAME, CURRENT PROGRAM, AND LIVE BADGE
class ChannelTile extends StatelessWidget {
  final Channel channel;
  final String? currentProgram;
  final double? programProgress;
  final VoidCallback? onSelect;
  final bool autofocus;
  final FocusOnKeyEventCallback? onKeyEvent;

  const ChannelTile({
    super.key,
    required this.channel,
    this.currentProgram,
    this.programProgress,
    this.onSelect,
    this.autofocus = false,
    this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: TvCard(
        onSelect: onSelect,
        autofocus: autofocus,
        onKeyEvent: onKeyEvent,
        borderRadius: 10,
        scaleOnFocus: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 36,
                  height: 36,
                  color: kDeepBackground,
                  child: channel.logoUrl.isNotEmpty
                      ? Image.network(
                          channel.logoUrl,
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => _logoPlaceholder(),
                        )
                      : _logoPlaceholder(),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      channel.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (currentProgram != null &&
                        currentProgram!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        currentProgram!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: kTextDisabled,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (programProgress != null) ...[
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: programProgress!.clamp(0.0, 1.0),
                            minHeight: 2,
                            backgroundColor: kTextDisabled.withValues(
                              alpha: 0.20,
                            ),
                            color: kAccentPurple.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),

              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.tv, color: kTextDisabled, size: 20),
    );
  }
}

class LiveChannelsList extends ConsumerStatefulWidget {
  final String? categoryId;
  final String categoryName;
  final bool isMainColumn;
  final int columnIndex;

  const LiveChannelsList({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.isMainColumn,
    this.columnIndex = 0,
  });

  @override
  ConsumerState<LiveChannelsList> createState() => _LiveChannelsListState();
}

class _LiveChannelsListState extends ConsumerState<LiveChannelsList> {
  DateTime? _lastLeftPress;
  DateTime? _lastRightPress;
  late final ScrollController _scrollController;
  Timer? _saveDebounce;
  bool _restored = false;

  String get _prefsKey =>
      'live_scroll_col_${widget.columnIndex}_${widget.categoryId ?? 'all'}';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || !_scrollController.hasClients) return;
      final prefs = await SharedPreferences.getInstance();
      final offset = _scrollController.offset;
      if (offset > 0) {
        await prefs.setDouble(_prefsKey, offset);
      } else {
        await prefs.remove(_prefsKey);
      }
    });
  }

  Future<void> _restoreScrollPosition() async {
    if (_restored || !mounted || !_scrollController.hasClients) return;
    final prefs = await SharedPreferences.getInstance();
    final savedOffset = prefs.getDouble(_prefsKey);
    if (savedOffset != null &&
        savedOffset > 0 &&
        mounted &&
        _scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        _scrollController.jumpTo(savedOffset.clamp(0.0, maxScroll));
        _restored = true;
      }
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channelAsync = ref.watch(
      channelsByCategoryProvider(widget.categoryId),
    );

    if (channelAsync.hasValue && !_restored) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreScrollPosition();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isMainColumn && widget.categoryName.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: kAccentPurple,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.categoryName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ] else
          const SizedBox(height: 12),

        Expanded(
          child: ListView.builder(
            key: PageStorageKey(
              'live_col_${widget.columnIndex}_${widget.categoryId ?? 'all'}',
            ),
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: channelAsync.valueOrNull?.length ?? 0,
            itemBuilder: (context, index) {
              final channel = channelAsync.value![index];
              return ChannelTile(
                channel: channel,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      FocusScope.of(
                        context,
                      ).focusInDirection(TraversalDirection.down);
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      FocusScope.of(
                        context,
                      ).focusInDirection(TraversalDirection.up);
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                      if (widget.columnIndex == 2) {
                        final now = DateTime.now();
                        if (_lastRightPress != null &&
                            now.difference(_lastRightPress!) <
                                const Duration(milliseconds: 500)) {
                          _lastRightPress = null;
                          ref.read(tabFocusControllerProvider)?.focusTab(0);
                        } else {
                          _lastRightPress = now;
                        }
                      } else {
                        FocusScope.of(
                          context,
                        ).focusInDirection(TraversalDirection.right);
                      }
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      if (widget.columnIndex == 0) {
                        final now = DateTime.now();
                        if (_lastLeftPress != null &&
                            now.difference(_lastLeftPress!) <
                                const Duration(milliseconds: 500)) {
                          _lastLeftPress = null;
                          ref.read(tabFocusControllerProvider)?.focusTab(0);
                        } else {
                          _lastLeftPress = now;
                        }
                      } else {
                        FocusScope.of(
                          context,
                        ).focusInDirection(TraversalDirection.left);
                      }
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                onSelect: () {
                  Navigator.of(context).pushNamed(
                    '/player',
                    arguments: {'type': 'live', 'channel': channel},
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
