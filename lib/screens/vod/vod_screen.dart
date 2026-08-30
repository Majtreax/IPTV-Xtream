import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_xtream/app/theme.dart';
import 'package:iptv_xtream/models/vod_model.dart';
import 'package:iptv_xtream/models/category_model.dart';
import 'package:iptv_xtream/widgets/category_list_item.dart';
import 'package:iptv_xtream/widgets/last_played_banner.dart';
import 'package:iptv_xtream/providers/vod_provider.dart';
import 'package:iptv_xtream/providers/category_provider.dart';
import 'package:iptv_xtream/providers/last_played_provider.dart';
import 'package:iptv_xtream/providers/tab_focus_provider.dart';
import 'package:iptv_xtream/screens/vod/vod_details_screen.dart';
import 'package:iptv_xtream/widgets/loading_indicator.dart';
import 'package:iptv_xtream/widgets/tv_card.dart';

class VodScreen extends ConsumerStatefulWidget {
  final String? categoryId;
  final String contentType;

  const VodScreen({super.key, this.categoryId, required this.contentType});

  @override
  ConsumerState<VodScreen> createState() => _VodScreenState();
}

class _VodScreenState extends ConsumerState<VodScreen> {
  String? _activeCategoryId;

  StateNotifierProvider<VodNotifier, VodState> get _provider =>
      widget.contentType == 'series' ? seriesProvider : moviesProvider;

  void _loadContent(String? catId) {
    final state = ref.read(_provider);
    final notifier = ref.read(_provider.notifier);
    if (state.items.isEmpty || state.activeCategoryId != catId) {
      if (widget.contentType == 'series') {
        final allowed = ref
            .read(categoryProvider)
            .seriesCategories
            .map((c) => c.id)
            .toSet();
        notifier.loadSeries(categoryId: catId, allowedCategoryIds: allowed);
      } else {
        final allowed = ref
            .read(categoryProvider)
            .movieCategories
            .map((c) => c.id)
            .toSet();
        notifier.loadMovies(categoryId: catId, allowedCategoryIds: allowed);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catState = ref.read(categoryProvider);
      final savedCat = widget.contentType == 'series'
          ? catState.selectedSeriesCategoryId
          : catState.selectedMovieCategoryId;

      _activeCategoryId = widget.categoryId ?? savedCat;

      final cats = widget.contentType == 'series'
          ? catState.seriesCategories
          : catState.movieCategories;

      if (_activeCategoryId != null &&
          cats.isNotEmpty &&
          !cats.any((c) => c.id == _activeCategoryId)) {
        _activeCategoryId = null;
      }

      setState(() {});
      _loadContent(_activeCategoryId);
    });
  }

  @override
  void didUpdateWidget(VodScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentType != widget.contentType) {
      final catState = ref.read(categoryProvider);
      final savedCat = widget.contentType == 'series'
          ? catState.selectedSeriesCategoryId
          : catState.selectedMovieCategoryId;
      _activeCategoryId = savedCat;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadContent(_activeCategoryId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(categoryProvider, (previous, next) {
      if (previous?.isLoading == true &&
          !next.isLoading &&
          next.errorMessage == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadContent(_activeCategoryId);
        });
      }
    });

    final isSeries = widget.contentType == 'series';
    final lastMovie = ref.watch(lastMovieProvider);
    final lastSeries = ref.watch(lastSeriesProvider);
    final lastVod = isSeries ? lastSeries : lastMovie;

    String? bannerSubtitle;
    String? bannerProgressText;
    double? bannerProgress;
    if (lastVod != null) {
      final baseSub = isSeries && lastVod.episode != null
          ? 'S${lastVod.seasonNumber ?? 1} E${lastVod.episode!.episodeNum}${lastVod.episode!.title.isNotEmpty ? ' · ${lastVod.episode!.title}' : ''}'
          : (lastVod.item.genre ?? '');
      bannerSubtitle = baseSub.isNotEmpty ? baseSub : null;

      if (lastVod.positionMs != null && lastVod.positionMs! > 10000) {
        final playedMins = (lastVod.positionMs! / 60000).round();
        if (playedMins <= 1) {
          bannerProgressText = '1 MINUTE WATCHED';
        } else {
          bannerProgressText = '$playedMins MINUTES WATCHED';
        }
        if (lastVod.durationMs != null && lastVod.durationMs! > 60000) {
          bannerProgress =
              (lastVod.positionMs! / lastVod.durationMs!).clamp(0.01, 1.0);
        }
      }
    }

    return Column(
      children: [
        if (lastVod != null) ...[
          LastPlayedBanner(
            title: lastVod.item.name,
            subtitle: bannerSubtitle,
            progressText: bannerProgressText,
            imageUrl: lastVod.item.coverUrl,
            badgeText: 'CONTINUE WATCHING',
            progressPercent: bannerProgress,
            onTap: () {
              Navigator.of(context).pushNamed(
                '/player',
                arguments: isSeries
                    ? {
                        'type': 'series',
                        'movieItem': lastVod.item,
                        'episode': lastVod.episode,
                        'seasonNumber': lastVod.seasonNumber ?? 1,
                        'streamUrl': lastVod.streamUrl,
                        'startPositionMs': lastVod.positionMs,
                      }
                    : {
                        'type': 'movie',
                        'movieItem': lastVod.item,
                        'streamUrl': lastVod.streamUrl,
                        'startPositionMs': lastVod.positionMs,
                      },
              );
            },
          ),
          const SizedBox(height: 8),
        ],

        FocusTraversalGroup(
          child: _VodHeader(
            contentType: widget.contentType,
            activeCategoryId: _activeCategoryId,
            onCategoryChanged: (id) {
              setState(() => _activeCategoryId = id);
              if (widget.contentType == 'series') {
                ref.read(categoryProvider.notifier).selectSeriesCategory(id);
              } else {
                ref.read(categoryProvider.notifier).selectMovieCategory(id);
              }
              _loadContent(id);
            },
            onSearchChanged: (query) {
              ref.read(_provider.notifier).search(query);
            },
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: FocusTraversalGroup(
            child: _VodContent(
              contentType: widget.contentType,
              categoryId: _activeCategoryId,
            ),
          ),
        ),
      ],
    );
  }
}

class _VodHeader extends ConsumerStatefulWidget {
  final String contentType;
  final String? activeCategoryId;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;

  const _VodHeader({
    required this.contentType,
    required this.activeCategoryId,
    required this.onCategoryChanged,
    required this.onSearchChanged,
  });

  @override
  ConsumerState<_VodHeader> createState() => _VodHeaderState();
}

class _VodHeaderState extends ConsumerState<_VodHeader> {
  bool _isCatFocused = false;

  late final FocusNode _catFocusNode = FocusNode();
  late final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _searchCloseFocusNode = FocusNode();
  final GlobalKey _categoryButtonKey = GlobalKey();
  final _searchController = TextEditingController();
  DateTime? _lastLeftPress;
  DateTime? _lastRightPress;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _searchCloseFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _catFocusNode.dispose();
    _searchFocusNode.dispose();
    _searchCloseFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: FocusTraversalGroup(
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(32),
            decoration: buildDialogDecoration(radius: 20, blurRadius: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        controller: _searchController,
                        onChanged: widget.onSearchChanged,
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 16,
                        ),
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Search Query',
                          floatingLabelAlignment: FloatingLabelAlignment.center,
                          hintText: 'Type to search...',
                          isDense: true,
                        ),
                        onSubmitted: (_) {
                          Navigator.of(context).pop();
                          _searchFocusNode.requestFocus();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCategoryPicker(
    BuildContext context,
    List<Category> categories,
    String allText,
  ) {
    final RenderBox button =
        _categoryButtonKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Stack(
        children: [
          Positioned(
            left: position.left,
            top: position.top + button.size.height + 8,
            width: button.size.width,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight:
                      overlay.size.height -
                      position.top -
                      button.size.height -
                      32,
                ),
                decoration: buildDialogDecoration(),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shrinkWrap: true,
                  itemCount: categories.length + 1,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: kTextDisabled.withValues(alpha: 0.1),
                  ),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isActive = widget.activeCategoryId == null;
                      return CategoryListItem(
                        label: allText,
                        isActive: isActive,
                        autofocus: isActive,
                        onTap: () {
                          widget.onCategoryChanged(null);
                          Navigator.pop(ctx);
                        },
                      );
                    }
                    final cat = categories[index - 1];
                    final isActive = widget.activeCategoryId == cat.id;
                    return CategoryListItem(
                      label: cat.name,
                      isActive: isActive,
                      autofocus: isActive,
                      onTap: () {
                        widget.onCategoryChanged(cat.id);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSeries = widget.contentType == 'series';
    final movieCats = isSeries
        ? ref.watch(seriesCategoriesProvider)
        : ref.watch(movieCategoriesProvider);
    final allText = isSeries ? 'ALL SERIES' : 'ALL MOVIES';
    final groupIcon = isSeries
        ? Icons.video_library_rounded
        : Icons.movie_creation_rounded;
    String title = allText;
    if (widget.activeCategoryId != null) {
      final match = movieCats.where((c) => c.id == widget.activeCategoryId);
      if (match.isNotEmpty) title = match.first.name;
    }

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Focus(
            focusNode: _catFocusNode,
            onFocusChange: (f) => setState(() => _isCatFocused = f),
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.enter) {
                  _showCategoryPicker(context, movieCats, allText);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _searchFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  final now = DateTime.now();
                  if (_lastLeftPress != null &&
                      now.difference(_lastLeftPress!) <
                          const Duration(milliseconds: 500)) {
                    _lastLeftPress = null;
                    final targetTab = widget.contentType == 'series' ? 2 : 1;
                    ref.read(tabFocusControllerProvider)?.focusTab(targetTab);
                  } else {
                    _lastLeftPress = now;
                  }
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              onTap: () => _showCategoryPicker(context, movieCats, allText),
              child: AnimatedContainer(
                key: _categoryButtonKey,
                duration: const Duration(milliseconds: 150),
                padding: kPickerPadding,
                decoration: buildCategoryPickerDecoration(
                  isFocused: _isCatFocused,
                ),
                child: Row(
                  children: [
                    Icon(groupIcon, color: kAccentPurple, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: _isCatFocused ? kAccentPurple : kTextPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: _isCatFocused ? kAccentPurple : kTextDisabled,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: Focus(
            focusNode: _searchFocusNode,
            onFocusChange: (f) => setState(() {}),
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.enter) {
                  _showSearchDialog();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _catFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  if (_searchController.text.isNotEmpty) {
                    _searchCloseFocusNode.requestFocus();
                  } else {
                    final now = DateTime.now();
                    if (_lastRightPress != null &&
                        now.difference(_lastRightPress!) <
                            const Duration(milliseconds: 500)) {
                      _lastRightPress = null;
                      final targetTab = widget.contentType == 'series' ? 2 : 1;
                      ref.read(tabFocusControllerProvider)?.focusTab(targetTab);
                    } else {
                      _lastRightPress = now;
                    }
                  }
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              onTap: _showSearchDialog,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: kPickerPadding,
                decoration: buildCategoryPickerDecoration(
                  isFocused: _searchFocusNode.hasFocus,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: _searchFocusNode.hasFocus
                          ? kAccentPurple
                          : kTextPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'SEARCH ${widget.contentType == 'series' ? 'SERIES' : 'MOVIES'}'
                            : _searchController.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: _searchFocusNode.hasFocus
                              ? kAccentPurple
                              : kTextPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.search_rounded,
                      color: Colors.transparent,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_searchController.text.isNotEmpty) ...[
          const SizedBox(width: 8),
          Focus(
            focusNode: _searchCloseFocusNode,
            onFocusChange: (f) => setState(() {}),
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter)) {
                _searchController.clear();
                widget.onSearchChanged('');
                _searchFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowRight) {
                final now = DateTime.now();
                if (_lastRightPress != null &&
                    now.difference(_lastRightPress!) <
                        const Duration(milliseconds: 500)) {
                  _lastRightPress = null;
                  final targetTab = widget.contentType == 'series' ? 2 : 1;
                  ref.read(tabFocusControllerProvider)?.focusTab(targetTab);
                } else {
                  _lastRightPress = now;
                }
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              onTap: () {
                _searchController.clear();
                widget.onSearchChanged('');
                _searchFocusNode.requestFocus();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 38,
                height: 38,
                decoration: kAppBackgroundDecoration.copyWith(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _searchCloseFocusNode.hasFocus
                        ? kAccentPurple
                        : Colors.white.withValues(alpha: 0.08),
                    width: _searchCloseFocusNode.hasFocus ? 2 : 1.5,
                  ),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: _searchCloseFocusNode.hasFocus
                      ? kAccentPurple
                      : kTextSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VodContent extends ConsumerStatefulWidget {
  final String contentType;
  final String? categoryId;
  const _VodContent({required this.contentType, this.categoryId});

  @override
  ConsumerState<_VodContent> createState() => _VodContentState();
}

class _VodContentState extends ConsumerState<_VodContent> {
  final Map<int, FocusNode> _nodes = {};
  DateTime? _lastLeftPress;
  DateTime? _lastRightPress;

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.contentType == 'series'
        ? seriesProvider
        : moviesProvider;
    final vodState = ref.watch(provider);
    final items = vodState.filteredItems;

    if (items.isEmpty) {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 24, height: 24, child: LoadingIndicator()),
            const SizedBox(width: 16),
            Text(
              'Loading VODs...',
              style: kTextStyleBody.copyWith(color: kTextSecondary),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 9,
        childAspectRatio: 0.56,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final node = _nodes.putIfAbsent(index, () => FocusNode());
        return _VodCard(
          key: ValueKey(items[index].streamId),
          item: items[index],
          focusNode: node,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                if ((index + 1) % 9 == 0 || index == items.length - 1) {
                  final now = DateTime.now();
                  if (_lastRightPress != null &&
                      now.difference(_lastRightPress!) <
                          const Duration(milliseconds: 500)) {
                    _lastRightPress = null;
                    final targetTab = widget.contentType == 'series' ? 2 : 1;
                    ref.read(tabFocusControllerProvider)?.focusTab(targetTab);
                  } else {
                    _lastRightPress = now;
                  }
                  return KeyEventResult.handled;
                } else if (index + 1 < items.length) {
                  _nodes[index + 1]?.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                if (index % 9 == 0) {
                  final now = DateTime.now();
                  if (_lastLeftPress != null &&
                      now.difference(_lastLeftPress!) <
                          const Duration(milliseconds: 500)) {
                    _lastLeftPress = null;
                    final targetTab = widget.contentType == 'series' ? 2 : 1;
                    ref.read(tabFocusControllerProvider)?.focusTab(targetTab);
                  } else {
                    _lastLeftPress = now;
                  }
                  return KeyEventResult.handled;
                } else if (index - 1 >= 0) {
                  _nodes[index - 1]?.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
        );
      },
    );
  }
}

class _VodCard extends StatelessWidget {
  final VodItem item;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  const _VodCard({
    super.key,
    required this.item,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return TvCard(
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      padding: EdgeInsets.zero,
      borderRadius: 10,
      onSelect: () {
        showDialog(
          context: context,
          barrierColor: kOverlayDimBackground,
          builder: (ctx) => VodDetails(item: item),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              child: item.coverUrl != null && item.coverUrl!.isNotEmpty
                  ? Image.network(
                      item.coverUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, _, _) => _posterPlaceholder(),
                    )
                  : _posterPlaceholder(),
            ),
          ),

          // VOD TITLE AND METADATA CONTAINER BELOW BANNER
          Container(
            height: 58,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.name,
                  style: kTextStyleBody.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (item.rating != null && item.rating! > 0) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: kAccentPurple,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        item.rating!.toStringAsFixed(1),
                        style: kTextStyleCaption.copyWith(
                          color: kAccentPurple,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (item.releaseDate != null &&
                        item.releaseDate!.length >= 4)
                      Text(
                        item.releaseDate!.substring(0, 4),
                        style: kTextStyleCaption.copyWith(
                          color: kTextDisabled,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _posterPlaceholder() {
    return Container(
      color: kSurfaceCard,
      child: const Center(
        child: Icon(Icons.movie_outlined, size: 40, color: kTextDisabled),
      ),
    );
  }
}
