import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_xtream/app/theme.dart';
import 'package:iptv_xtream/screens/live/live_dashboard_screen.dart';
import 'package:iptv_xtream/screens/vod/vod_screen.dart';
import 'package:iptv_xtream/providers/category_provider.dart';
import 'package:iptv_xtream/providers/auth_provider.dart';
import 'package:iptv_xtream/providers/last_played_provider.dart';
import 'package:iptv_xtream/providers/settings_provider.dart';
import 'package:iptv_xtream/providers/tab_focus_provider.dart';
import 'package:iptv_xtream/widgets/loading_indicator.dart';
import 'package:iptv_xtream/widgets/app_button.dart';
import 'package:iptv_xtream/widgets/tab_item.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _activeTab = 0; // 0=LIVE, 1=MOVIES, 2=SERIES
  final List<FocusNode> _tabNodes = [FocusNode(), FocusNode(), FocusNode()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(categoryProvider.notifier).loadAllCategories();
      ref.read(tabFocusControllerProvider.notifier).state = TabFocusController(
        tabNodes: _tabNodes,
      );
    });
  }

  @override
  void dispose() {
    for (var node in _tabNodes) {
      node.dispose();
    }
    super.dispose();
  }

  DateTime? _lastPressedAt;
  bool _showExitToast = false;

  void _handleBackPress() {
    final now = DateTime.now();
    if (_lastPressedAt == null ||
        now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
      _lastPressedAt = now;
      setState(() => _showExitToast = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _showExitToast = false);
        }
      });
    } else {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: kAppBackgroundDecoration,
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.goBack ||
                      event.logicalKey == LogicalKeyboardKey.escape)) {
                _handleBackPress();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TOP TAB BAR
                      FocusTraversalGroup(
                        policy: WidgetOrderTraversalPolicy(),
                        child: Builder(
                          builder: (ctx) {
                            return SizedBox(
                              width: double.infinity,
                              child: Row(
                                children: [
                                  // LEFT: LOGO AND TITLE
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: buildGlassyPillDecoration(
                                            glowAlpha: 0.5,
                                            blurRadius: 40,
                                            spreadRadius: 4,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Image.asset(
                                                'assets/images/logo.png',
                                                height: 42,
                                                fit: BoxFit.contain,
                                              ),
                                              const SizedBox(width: 12),
                                              ShaderMask(
                                                shaderCallback: (bounds) =>
                                                    const LinearGradient(
                                                      colors: [
                                                        Color(0xFFE9D5FF),
                                                        kAccentPurple,
                                                        kFocusedButtonColor,
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                    ).createShader(bounds),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: const [
                                                    Text(
                                                      'IPTV',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white,
                                                        letterSpacing: 3.2,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'XTREAM',
                                                      style: TextStyle(
                                                        fontSize: 22,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: Colors.white,
                                                        letterSpacing: 1.2,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // CENTER: TABS
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TabItem(
                                          title: 'LIVE TV',
                                          icon: Icons.live_tv_rounded,
                                          isActive: _activeTab == 0,
                                          autofocus: true,
                                          focusNode: _tabNodes[0],
                                          onFocus: () =>
                                              setState(() => _activeTab = 0),
                                          onFocusUp: () => _tabNodes[_activeTab]
                                              .requestFocus(),
                                          onTap: () =>
                                              setState(() => _activeTab = 0),
                                        ),
                                        const SizedBox(width: 24),
                                        TabItem(
                                          title: 'MOVIES',
                                          icon: Icons.movie_creation_rounded,
                                          isActive: _activeTab == 1,
                                          focusNode: _tabNodes[1],
                                          onFocus: () =>
                                              setState(() => _activeTab = 1),
                                          onFocusUp: () => _tabNodes[_activeTab]
                                              .requestFocus(),
                                          onTap: () =>
                                              setState(() => _activeTab = 1),
                                        ),
                                        const SizedBox(width: 24),
                                        TabItem(
                                          title: 'SERIES',
                                          icon: Icons.video_library_rounded,
                                          isActive: _activeTab == 2,
                                          focusNode: _tabNodes[2],
                                          onFocus: () =>
                                              setState(() => _activeTab = 2),
                                          onFocusUp: () => _tabNodes[_activeTab]
                                              .requestFocus(),
                                          onTap: () =>
                                              setState(() => _activeTab = 2),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // RIGHT: SETTINGS
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: StatefulBuilder(
                                        builder: (context, setState) {
                                          return Focus(
                                            onFocusChange: (hasFocus) =>
                                                setState(() {}),
                                            onKeyEvent: (node, event) {
                                              if (event is KeyDownEvent &&
                                                  (event.logicalKey ==
                                                          LogicalKeyboardKey
                                                              .select ||
                                                      event.logicalKey ==
                                                          LogicalKeyboardKey
                                                              .enter)) {
                                                _showSettingsDialog(
                                                  context,
                                                  ref,
                                                );
                                                return KeyEventResult.handled;
                                              }
                                              return KeyEventResult.ignored;
                                            },
                                            child: Builder(
                                              builder: (ctx) {
                                                final isFocused = Focus.of(
                                                  ctx,
                                                ).hasFocus;
                                                return GestureDetector(
                                                  onTap: () {
                                                    _showSettingsDialog(
                                                      context,
                                                      ref,
                                                    );
                                                  },
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 200,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 8,
                                                        ),
                                                    decoration: buildGlassyPillDecoration()
                                                        .copyWith(
                                                          border: Border.all(
                                                            color: isFocused
                                                                ? kAccentPurple
                                                                : Colors.white
                                                                      .withValues(
                                                                        alpha:
                                                                            0.08,
                                                                      ),
                                                            width: isFocused
                                                                ? 2
                                                                : 1.5,
                                                          ),
                                                        ),
                                                    child: Icon(
                                                      Icons.settings_rounded,
                                                      color: isFocused
                                                          ? kAccentPurple
                                                          : Colors.white,
                                                      size: 24,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // CONTENT
                      Expanded(
                        child: _activeTab == 0
                            ? const LiveDashboardScreen()
                            : (_activeTab == 1
                                  ? const VodScreen(contentType: 'movie')
                                  : const VodScreen(contentType: 'series')),
                      ),
                    ],
                  ),
                  if (_showExitToast)
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: kSurfaceCard.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: kAccentPurple.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'PRESS BACK AGAIN TO EXIT',
                            style: TextStyle(
                              color: kTextPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.1,
                            ),
                          ),
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

  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      routeSettings: const RouteSettings(name: '/settings_dialog'),
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Consumer(
        builder: (context, watchRef, child) {
          final authState = watchRef.watch(authProvider);
          final serverInfo = authState.serverInfo;

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 550,
              padding: const EdgeInsets.all(32),
              decoration: buildDialogDecoration(radius: 20, blurRadius: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.settings_rounded,
                        size: 20,
                        color: kTextSecondary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'IPTV Settings',
                        style: TextStyle(
                          color: kTextSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (serverInfo != null) ...[
                    _buildInfoRow('Server URL', serverInfo.serverUrl),
                    const SizedBox(height: 16),
                    _buildInfoRow('Username', serverInfo.username),
                    const SizedBox(height: 16),
                    _buildInfoRow('Password', '•' * serverInfo.password.length),
                    const SizedBox(height: 16),
                  ] else ...[
                    const Text(
                      'Invalid IPTV Credentials.',
                      style: TextStyle(color: kTextSecondary),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildFontSizeRow(watchRef),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (context) {
                      final isRefreshing =
                          authState.isLoading ||
                          watchRef.watch(categoryProvider).isLoading;
                      if (isRefreshing) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: LoadingIndicator(),
                            ),
                            SizedBox(width: 16),
                            Text(
                              'Refreshing...',
                              style: TextStyle(
                                color: kTextSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final isRefreshing =
                          authState.isLoading ||
                          watchRef.watch(categoryProvider).isLoading;
                      if (!isRefreshing) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            AppButton(
                              label: 'Refresh',
                              icon: Icons.refresh_rounded,
                              primary: true,
                              autofocus: false,
                              onPressed: () async {
                                await watchRef
                                    .read(authProvider.notifier)
                                    .restoreSession();
                                await Future.delayed(Duration.zero);
                                await watchRef
                                    .read(categoryProvider.notifier)
                                    .loadAllCategories();
                                if (!context.mounted) return;
                                Navigator.pop(context);
                              },
                            ),
                            AppButton(
                              label: 'Logout',
                              icon: Icons.logout_rounded,
                              primary: false,
                              onPressed: () {
                                watchRef
                                    .read(lastPlayedProvider.notifier)
                                    .clear();
                                watchRef.read(authProvider.notifier).logout();
                                Navigator.pop(ctx);
                              },
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kTextDisabled.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: kTextDisabled, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: kTextSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeRow(WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kTextDisabled.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 100,
            child: Text(
              'Font Size',
              style: TextStyle(color: kTextDisabled, fontSize: 14),
            ),
          ),
          Expanded(
            child: _FontSizeSelector(
              selectedLevel: settings.fontSizeLevel,
              onSelected: (level) {
                ref.read(settingsProvider.notifier).setFontSizeLevel(level);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FontSizeSelector extends StatelessWidget {
  final int selectedLevel;
  final ValueChanged<int> onSelected;

  const _FontSizeSelector({
    required this.selectedLevel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SegmentItem(
            level: 1,
            label: 'Standard',
            isSelected: selectedLevel == 1,
            onTap: () => onSelected(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SegmentItem(
            level: 2,
            label: 'Medium',
            isSelected: selectedLevel == 2,
            onTap: () => onSelected(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SegmentItem(
            level: 3,
            label: 'Large',
            isSelected: selectedLevel == 3,
            onTap: () => onSelected(3),
          ),
        ),
      ],
    );
  }
}

class _SegmentItem extends StatefulWidget {
  final int level;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentItem({
    required this.level,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SegmentItem> createState() => _SegmentItemState();
}

class _SegmentItemState extends State<_SegmentItem> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (f) {
        setState(() => _isFocused = f);
        if (f && !widget.isSelected) {
          // AUTO-APPLY FONT SIZE ON FOCUS
          widget.onTap();
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            node.nextFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            node.previousFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _focusNode.requestFocus();
          widget.onTap();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? kAccentPurple.withValues(alpha: _isFocused ? 0.35 : 0.20)
                  : (_isFocused || _isHovered
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.03)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isFocused
                    ? kFocusedButtonColor
                    : (widget.isSelected
                          ? kAccentPurple
                          : Colors.white.withValues(alpha: 0.1)),
                width: _isFocused || widget.isSelected ? 2 : 1,
              ),
              boxShadow: _isFocused || widget.isSelected
                  ? [
                      BoxShadow(
                        color: kAccentPurple.withValues(
                          alpha: _isFocused ? 0.35 : 0.18,
                        ),
                        blurRadius: _isFocused ? 12 : 8,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isSelected) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: kAccentPurple,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.isSelected || _isFocused
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: widget.isSelected || _isFocused
                          ? Colors.white
                          : kTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
