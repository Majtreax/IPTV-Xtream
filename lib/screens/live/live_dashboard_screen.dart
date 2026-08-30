import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_xtream/app/theme.dart';
import 'package:iptv_xtream/providers/category_provider.dart';
import 'package:iptv_xtream/providers/fav_groups_provider.dart';
import 'package:iptv_xtream/screens/live/live_channels_screen.dart';
import 'package:iptv_xtream/providers/last_played_provider.dart';
import 'package:iptv_xtream/providers/tab_focus_provider.dart';
import 'package:iptv_xtream/widgets/category_list_item.dart';
import 'package:iptv_xtream/widgets/last_played_banner.dart';
import 'package:iptv_xtream/models/category_model.dart';

class LiveDashboardScreen extends ConsumerWidget {
  const LiveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastChannel = ref.watch(lastChannelProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lastChannel != null) ...[
          LastPlayedBanner(
            title: lastChannel.name,
            subtitle: lastChannel.groupTitle.isNotEmpty
                ? lastChannel.groupTitle
                : null,
            imageUrl: lastChannel.logoUrl.isNotEmpty
                ? lastChannel.logoUrl
                : null,
            badgeText: 'LAST PLAYED',
            onTap: () {
              Navigator.of(context).pushNamed(
                '/player',
                arguments: {'type': 'live', 'channel': lastChannel},
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(child: _FavoriteColumn(columnIndex: 0)),
              SizedBox(width: 16),
              Expanded(child: _FavoriteColumn(columnIndex: 1)),
              SizedBox(width: 16),
              Expanded(child: _FavoriteColumn(columnIndex: 2)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FavoriteColumn extends ConsumerWidget {
  final int columnIndex;
  const _FavoriteColumn({required this.columnIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favGroups = ref.watch(favoriteGroupsProvider);
    String? selectedCategoryId = favGroups[columnIndex];

    if (selectedCategoryId != null) {
      final liveCats = ref.watch(liveCategoriesProvider);
      if (liveCats.isNotEmpty &&
          !liveCats.any((c) => c.id == selectedCategoryId)) {
        selectedCategoryId = null;
      }
    }

    return Column(
      children: [
        _CategoryPickerHeader(
          columnIndex: columnIndex,
          selectedCategoryId: selectedCategoryId,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: (columnIndex != 0 && selectedCategoryId == null)
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: kAppBackgroundDecoration.copyWith(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: kTextDisabled.withValues(alpha: 0.05),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Choose your favourite group to pin here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kTextSecondary,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ),
                )
              : LiveChannelsList(
                  key: ValueKey(selectedCategoryId ?? 'all'),
                  categoryId:
                      (selectedCategoryId == 'all' ||
                          selectedCategoryId == null)
                      ? null
                      : selectedCategoryId,
                  categoryName: '',
                  isMainColumn: columnIndex == 0,
                  columnIndex: columnIndex,
                ),
        ),
      ],
    );
  }
}

class _CategoryPickerHeader extends ConsumerStatefulWidget {
  final int columnIndex;
  final String? selectedCategoryId;
  const _CategoryPickerHeader({
    required this.columnIndex,
    this.selectedCategoryId,
  });

  @override
  ConsumerState<_CategoryPickerHeader> createState() =>
      _CategoryPickerHeaderState();
}

class _CategoryPickerHeaderState extends ConsumerState<_CategoryPickerHeader> {
  bool _isFocused = false;
  DateTime? _lastLeftPress;
  DateTime? _lastRightPress;

  void _showCategoryPicker(BuildContext context, List<Category> categories) {
    final RenderBox button = context.findRenderObject() as RenderBox;
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
                      final isActive =
                          widget.selectedCategoryId == null ||
                          widget.selectedCategoryId == 'all';
                      return CategoryListItem(
                        label: 'ALL CHANNELS',
                        isActive: isActive,
                        autofocus: isActive,
                        onTap: () {
                          ref
                              .read(favoriteGroupsProvider.notifier)
                              .setColumnCategory(widget.columnIndex, 'all');
                          Navigator.pop(ctx);
                        },
                      );
                    }
                    final cat = categories[index - 1];
                    final isActive = widget.selectedCategoryId == cat.id;
                    return CategoryListItem(
                      label: cat.name,
                      isActive: isActive,
                      autofocus: isActive,
                      onTap: () {
                        ref
                            .read(favoriteGroupsProvider.notifier)
                            .setColumnCategory(widget.columnIndex, cat.id);
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
    final liveCats = ref.watch(liveCategoriesProvider);
    String title = 'CATEGORIES';
    if (widget.selectedCategoryId != null &&
        widget.selectedCategoryId != 'all') {
      final match = liveCats.where((c) => c.id == widget.selectedCategoryId);
      if (match.isNotEmpty) title = match.first.name;
    } else if (widget.columnIndex == 0 || widget.selectedCategoryId == 'all') {
      title = 'ALL CHANNELS';
    }

    return Focus(
      onFocusChange: (f) => setState(() => _isFocused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            _showCategoryPicker(context, liveCats);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            FocusScope.of(context).focusInDirection(TraversalDirection.down);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            FocusScope.of(context).focusInDirection(TraversalDirection.up);
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
              FocusScope.of(context).focusInDirection(TraversalDirection.right);
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
              FocusScope.of(context).focusInDirection(TraversalDirection.left);
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => _showCategoryPicker(context, liveCats),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: kPickerPadding,
          decoration: buildCategoryPickerDecoration(isFocused: _isFocused),
          child: Row(
            children: [
              const Icon(Icons.live_tv_rounded, color: kAccentPurple, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: kTextStyleBody.copyWith(
                    color: _isFocused ? kAccentPurple : kTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: _isFocused ? kAccentPurple : kTextDisabled,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
