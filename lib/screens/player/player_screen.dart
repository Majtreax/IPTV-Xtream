import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_xtream/app/theme.dart';
import 'package:iptv_xtream/models/vod_model.dart';
import 'package:iptv_xtream/models/channel_model.dart';
import 'package:iptv_xtream/providers/channel_provider.dart';
import 'package:iptv_xtream/screens/player/player_controls_widget.dart';
import 'package:iptv_xtream/screens/player/channel_list_overlay_widget.dart';
import 'package:iptv_xtream/screens/player/audio_overlay_widget.dart';
import 'package:iptv_xtream/screens/player/subtitle_overlay_widget.dart';
import 'package:iptv_xtream/screens/player/volume_overlay_widget.dart';
import 'package:iptv_xtream/screens/vod/vod_details_screen.dart';
import 'package:iptv_xtream/providers/last_played_provider.dart';
import 'package:iptv_xtream/utils/language_helper.dart';

// FULL-SCREEN VIDEO PLAYER WITH AUTO-HIDING OVERLAY CONTROLS
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;
  final List<StreamSubscription> _subscriptions = [];

  bool _showControls = false;
  bool _showAudioPicker = false;
  bool _showSubtitlePicker = false;
  bool _showChannelOverlay = false;
  bool _showVolumeOverlay = false;
  Timer? _hideTimer;
  final FocusNode _playerFocusNode = FocusNode(debugLabel: 'PlayerRoot');
  final FocusNode _listButtonFocusNode = FocusNode(debugLabel: 'ListButton');
  final FocusNode _playButtonFocusNode = FocusNode(debugLabel: 'PlayButton');
  bool _argumentsParsed = false;
  final FocusScopeNode _controlsFocusScopeNode = FocusScopeNode(
    debugLabel: 'ControlsScope',
  );
  Duration? _pendingSeek;

  // STREAM STATE
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  List<Map<String, dynamic>> _audioTracks = [];
  List<Map<String, dynamic>> _subtitleTracks = [];
  int _activeAudioTrack = -1;
  int _activeSubtitleTrack = 0;

  // CONTENT INFO
  String _title = '';
  String _subtitle = '';
  String? _streamUrl;
  Channel? _currentChannel;
  VodItem? _currentMovieItem;
  String _contentType = 'live';
  bool _isSeekingHolding = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(
      _player,
      configuration: (Platform.isWindows || Platform.isMacOS)
          ? const VideoControllerConfiguration()
          : const VideoControllerConfiguration(
              enableHardwareAcceleration: false,
              androidAttachSurfaceAfterVideoParameters: false,
            ),
    );

    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      }),
    );
    _subscriptions.add(
      _player.stream.position.listen((pos) {
        if (mounted) {
          setState(() => _position = pos);
          _savePlaybackProgress();
        }
      }),
    );
    _subscriptions.add(
      _player.stream.duration.listen((dur) {
        if (mounted) {
          setState(() => _duration = dur);
          // SEEK TO SAVED POSITION ONCE MEDIA IS LOADED AND SEEKABLE
          if (dur.inSeconds > 0 && _pendingSeek != null) {
            final seekTo = _pendingSeek!;
            _pendingSeek = null;
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _player.seek(seekTo);
            });
          }
        }
      }),
    );
    _subscriptions.add(_player.stream.error.listen((_) {}));
    _subscriptions.add(
      _player.stream.tracks.listen((tracks) {
        if (mounted) {
          final validAudio = <Map<String, dynamic>>[];
          for (int i = 0; i < tracks.audio.length; i++) {
            final t = tracks.audio[i];
            final id = t.id.toLowerCase().trim();
            if (id != 'auto' && id != 'no' && id != 'none') {
              validAudio.add({
                'original_index': i,
                'id': t.id,
                'title': t.title ?? '',
                'language': t.language ?? '',
              });
            }
          }

          final validSubs = <Map<String, dynamic>>[
            {
              'original_index': -1,
              'id': 'no',
              'title': 'Off',
              'language': 'OFF',
            },
          ];
          for (int i = 0; i < tracks.subtitle.length; i++) {
            final s = tracks.subtitle[i];
            final id = s.id.toLowerCase().trim();
            if (id != 'auto' && id != 'no' && id != 'none') {
              validSubs.add({
                'original_index': i,
                'id': s.id,
                'title': s.title ?? '',
                'language': s.language ?? '',
              });
            }
          }

          setState(() {
            _audioTracks = LanguageHelper.filterAndDeduplicateTracks(
              validAudio,
              isSubtitle: false,
            );
            _subtitleTracks = LanguageHelper.filterAndDeduplicateTracks(
              validSubs,
              isSubtitle: true,
            );
          });
        }
      }),
    );
    _subscriptions.add(
      _player.stream.track.listen((track) {
        if (mounted) {
          final idx = _audioTracks.indexWhere((t) => t['id'] == track.audio.id);
          int sIdx = 0;
          final subId = track.subtitle.id.toLowerCase().trim();
          if (subId != 'no' && subId != 'none' && subId.isNotEmpty) {
            final found = _subtitleTracks.indexWhere(
              (s) => s['id'] == track.subtitle.id,
            );
            sIdx = found != -1 ? found : 0;
          }
          setState(() {
            _activeAudioTrack = idx;
            _activeSubtitleTrack = sIdx;
          });
        }
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argumentsParsed) {
      _parseArguments();
      _argumentsParsed = true;
    }
  }

  DateTime? _lastPosSavedTime;
  void _savePlaybackProgress({bool force = false}) {
    if (_contentType != 'movie' &&
        _contentType != 'vod' &&
        _contentType != 'series') {
      return;
    }
    if (_position.inSeconds < 3) return;
    final now = DateTime.now();
    if (!force &&
        _lastPosSavedTime != null &&
        now.difference(_lastPosSavedTime!) < const Duration(seconds: 4)) {
      return;
    }
    _lastPosSavedTime = now;
    ref
        .read(lastPlayedProvider.notifier)
        .updatePlaybackPosition(
          type: _contentType,
          positionMs: _position.inMilliseconds,
          durationMs: _duration.inMilliseconds > 0
              ? _duration.inMilliseconds
              : null,
        );
  }

  void _parseArguments() {
    final args = ModalRoute.of(context)?.settings.arguments;
    int? startPosMs;
    if (args is Map<String, dynamic>) {
      final type = args['type'] as String?;
      if (type != null) _contentType = type;
      startPosMs = args['startPositionMs'] as int?;

      if (_contentType == 'live') {
        _showControls = false;
        final channel = args['channel'] as Channel?;
        if (channel != null) {
          _currentChannel = channel;
          _title = channel.name;
          _subtitle = channel.groupTitle;
          _streamUrl = channel.streamUrl;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(lastPlayedProvider.notifier).setLastChannel(channel);
            ref.read(channelProvider.notifier).loadChannels();
          });
        }
      } else if (_contentType == 'vod' ||
          _contentType == 'movie' ||
          _contentType == 'series') {
        _showControls = true;
        _startHideTimer();
        final item = args['movieItem'] as VodItem?;
        final episode = args['episode'];
        if (item != null) {
          _currentMovieItem = item;
          _title = item.name;
          _streamUrl = args['streamUrl'] as String? ?? '';
          if (episode != null && _contentType == 'series') {
            final seasonNum = (args['seasonNumber'] as int?) ?? 1;
            final epNum = episode.episodeNum as int? ?? 1;
            final epTitle = (episode.title as String?) ?? '';
            _subtitle =
                'S$seasonNum E$epNum${epTitle.isNotEmpty ? ' · $epTitle' : ''}';
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref
                  .read(lastPlayedProvider.notifier)
                  .setLastSeries(
                    item,
                    episode,
                    seasonNum,
                    _streamUrl!,
                    positionMs: startPosMs,
                  );
            });
          } else {
            _subtitle = item.genre ?? '';
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref
                  .read(lastPlayedProvider.notifier)
                  .setLastMovie(item, _streamUrl!, positionMs: startPosMs);
            });
          }
        }
      }
    }

    if (_streamUrl != null && _streamUrl!.isNotEmpty) {
      if (startPosMs != null && startPosMs > 5000) {
        _pendingSeek = Duration(milliseconds: startPosMs);
      }
      _player.open(Media(_streamUrl!));
    }
  }

  void _safeExitPlayer() {
    _savePlaybackProgress(force: true);
    _hideTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _player.stop().catchError((_) {});
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_showChannelOverlay ||
        _showAudioPicker ||
        _showSubtitlePicker ||
        _showVolumeOverlay ||
        _isSeekingHolding) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted &&
          _showControls &&
          !_showChannelOverlay &&
          !_showAudioPicker &&
          !_showSubtitlePicker &&
          !_showVolumeOverlay &&
          !_isSeekingHolding) {
        _controlsFocusScopeNode.focusedChild?.unfocus();
        setState(() => _showControls = false);
        _playerFocusNode.requestFocus();
      }
    });
  }

  void _showControlsAndResetTimer() {
    setState(() {
      _showControls = true;
    });
    _startHideTimer();
  }

  void _refreshLiveStream() {
    if (_streamUrl != null && _streamUrl!.isNotEmpty) {
      _player.open(Media(_streamUrl!));
    }
  }

  void _setVolume(double vol) {
    _player.setVolume(vol.clamp(0.0, 100.0));
    if (!_showVolumeOverlay) {
      _startHideTimer();
    }
  }

  @override
  void dispose() {
    _savePlaybackProgress(force: true);
    _hideTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _playerFocusNode.dispose();
    _controlsFocusScopeNode.dispose();
    _listButtonFocusNode.dispose();
    _playButtonFocusNode.dispose();
    _player.stop().catchError((_) {});
    _player.dispose().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = _audioTracks.length > 1;
    final hasSubs = _subtitleTracks.length > 1;

    // EXACT BUTTON CENTERS FROM SCREEN RIGHT EDGE
    // CONTAINER PADDING = 48, BUTTON = 52, GAP = 24
    // RIGHT-TO-LEFT ORDER: SUBTITLE, AUDIO, VOLUME
    // 1ST BUTTON CENTER = 48 + 26 = 74
    // 2ND BUTTON CENTER = 48 + 52 + 24 + 26 = 150
    // 3RD BUTTON CENTER = 48 + 52 + 24 + 52 + 24 + 26 = 226
    const double btn1Center = 74.0;
    const double btn2Center = 150.0;
    const double btn3Center = 226.0;
    const double popupHalfW = 38.0;
    const double volHalfW = 28.0;

    final double subsOffset = btn1Center - popupHalfW;
    final double audioOffset = (hasSubs ? btn2Center : btn1Center) - popupHalfW;
    final double volumeOffset =
        ((hasSubs && hasAudio)
            ? btn3Center
            : (hasSubs || hasAudio)
            ? btn2Center
            : btn1Center) -
        volHalfW;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _safeExitPlayer();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onHover: (_) => _showControlsAndResetTimer(),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (_showChannelOverlay ||
                  _showAudioPicker ||
                  _showSubtitlePicker ||
                  _showVolumeOverlay) {
                return;
              }
              if (_showControls) {
                _controlsFocusScopeNode.focusedChild?.unfocus();
                setState(() => _showControls = false);
              } else {
                _showControlsAndResetTimer();
              }
            },
            child: Focus(
              focusNode: _playerFocusNode,
              autofocus: true,
              onKeyEvent: _handleKeyEvent,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Video(
                      controller: _videoController,
                      controls: NoVideoControls,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(48, 32, 48, 20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.8),
                                  Colors.black.withValues(alpha: 0.4),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                Flexible(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 18,
                                        sigmaY: 18,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: kAccentPurple.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: kAccentPurple.withValues(
                                              alpha: 0.45,
                                            ),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: kAccentPurple.withValues(
                                                alpha: 0.25,
                                              ),
                                              blurRadius: 20,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _title,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (_subtitle.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                _subtitle,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: kAccentPurple
                                                      .withValues(alpha: 0.95),
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.3,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
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
                  ),

                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedSlide(
                      offset: _showControls ? Offset.zero : const Offset(0, 1),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: _showControls ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: IgnorePointer(
                          ignoring: !_showControls,
                          child: ExcludeFocus(
                            excluding:
                                _showChannelOverlay ||
                                _showAudioPicker ||
                                _showSubtitlePicker ||
                                _showVolumeOverlay,
                            child: FocusScope(
                              node: _controlsFocusScopeNode,
                              child: PlayerControls(
                                contentType: _contentType,
                                isPlaying: _isPlaying,
                                position: _position,
                                duration: _duration,
                                listButtonFocusNode: _listButtonFocusNode,
                                playButtonFocusNode: _playButtonFocusNode,
                                onSeekHoldingChanged: (holding) {
                                  setState(() {
                                    _isSeekingHolding = holding;
                                  });
                                  if (holding) {
                                    _hideTimer?.cancel();
                                  } else {
                                    _startHideTimer();
                                  }
                                },
                                hasAudioTracks: hasAudio,
                                hasSubtitles: hasSubs,
                                isSubtitleActive: _showSubtitlePicker,
                                onRefresh: _refreshLiveStream,
                                onPlayPause: () {
                                  if (_contentType == 'live') {
                                    _refreshLiveStream();
                                  } else {
                                    _player.playOrPause();
                                  }
                                  _startHideTimer();
                                },
                                onRewind: () {
                                  final newPos =
                                      _position - const Duration(seconds: 10);
                                  _player.seek(
                                    newPos < Duration.zero
                                        ? Duration.zero
                                        : newPos,
                                  );
                                  _startHideTimer();
                                },
                                onForward: () {
                                  final newPos =
                                      _position + const Duration(seconds: 10);
                                  _player.seek(
                                    newPos > _duration ? _duration : newPos,
                                  );
                                  _startHideTimer();
                                },
                                onAudioTrack: () {
                                  setState(() {
                                    _showAudioPicker = !_showAudioPicker;
                                    _showSubtitlePicker = false;
                                    _showVolumeOverlay = false;
                                  });
                                  if (_showAudioPicker) {
                                    _hideTimer?.cancel();
                                  } else {
                                    _startHideTimer();
                                  }
                                },
                                onSubtitleTap: () {
                                  setState(() {
                                    _showSubtitlePicker = !_showSubtitlePicker;
                                    _showAudioPicker = false;
                                    _showVolumeOverlay = false;
                                  });
                                  if (_showSubtitlePicker) {
                                    _hideTimer?.cancel();
                                  } else {
                                    _startHideTimer();
                                  }
                                },
                                onStop: _safeExitPlayer,
                                onChannelOverlay: () {
                                  if (_contentType == 'series' &&
                                      _currentMovieItem != null) {
                                    _hideTimer?.cancel();
                                    _controlsFocusScopeNode.focusedChild
                                        ?.unfocus();
                                    setState(() {
                                      _showControls = false;
                                      _showChannelOverlay = false;
                                      _showAudioPicker = false;
                                      _showSubtitlePicker = false;
                                      _showVolumeOverlay = false;
                                    });
                                    showDialog(
                                      context: context,
                                      barrierColor: kOverlayDimBackground,
                                      builder: (ctx) => VodDetails(
                                        item: _currentMovieItem!,
                                        isOpenedFromPlayer: true,
                                      ),
                                    ).then((result) {
                                      if (mounted) {
                                        _playerFocusNode.requestFocus();
                                      }
                                      if (result != null &&
                                          result is Map<String, dynamic>) {
                                        final ep = result['episode'];
                                        final seasonNum =
                                            (result['seasonNumber'] as int?) ??
                                            1;
                                        final streamUrl =
                                            result['streamUrl'] as String?;
                                        if (ep != null &&
                                            streamUrl != null &&
                                            streamUrl.isNotEmpty) {
                                          final epNum =
                                              ep.episodeNum as int? ?? 1;
                                          final epTitle =
                                              (ep.title as String?) ?? '';
                                          setState(() {
                                            _streamUrl = streamUrl;
                                            _subtitle =
                                                'S$seasonNum E$epNum${epTitle.isNotEmpty ? ' · $epTitle' : ''}';
                                          });
                                          ref
                                              .read(lastPlayedProvider.notifier)
                                              .setLastSeries(
                                                _currentMovieItem!,
                                                ep,
                                                seasonNum,
                                                streamUrl,
                                              );
                                          _player.open(Media(streamUrl));
                                        }
                                      }
                                    });
                                  } else if (_contentType == 'live' ||
                                      _contentType == 'movie') {
                                    setState(() {
                                      _showChannelOverlay = true;
                                      _showAudioPicker = false;
                                      _showSubtitlePicker = false;
                                      _showVolumeOverlay = false;
                                      _showControls = false;
                                    });
                                  }
                                },
                                onSeek: (duration) {
                                  final clamped = Duration(
                                    milliseconds: duration.inMilliseconds.clamp(
                                      0,
                                      _duration.inMilliseconds,
                                    ),
                                  );
                                  _player.seek(clamped);
                                  _startHideTimer();
                                },
                                onVolumeTap: () {
                                  setState(() {
                                    _showVolumeOverlay = !_showVolumeOverlay;
                                    _showAudioPicker = false;
                                    _showSubtitlePicker = false;
                                  });
                                  if (_showVolumeOverlay) {
                                    _hideTimer?.cancel();
                                  } else {
                                    _startHideTimer();
                                  }
                                },
                                isVolumeActive: _showVolumeOverlay,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_showAudioPicker)
                    AudioOverlay(
                      tracks: _audioTracks,
                      activeTrackIndex: _activeAudioTrack,
                      rightOffset: audioOffset,
                      onTrackSelected: (index) {
                        if (index < _audioTracks.length) {
                          final originalIndex =
                              _audioTracks[index]['original_index'] as int?;
                          final tracks = _player.state.tracks.audio;
                          if (originalIndex != null &&
                              originalIndex < tracks.length) {
                            _player.setAudioTrack(tracks[originalIndex]);
                          }
                        }
                        setState(() => _showAudioPicker = false);
                        _startHideTimer();
                      },
                      onClose: () {
                        setState(() => _showAudioPicker = false);
                        _startHideTimer();
                      },
                    ),

                  if (_showSubtitlePicker)
                    SubtitleOverlay(
                      subtitles: _subtitleTracks,
                      activeSubtitleIndex: _activeSubtitleTrack,
                      rightOffset: subsOffset,
                      onSubtitleSelected: (index) {
                        if (index == 0) {
                          _player.setSubtitleTrack(SubtitleTrack.no());
                        } else if (index < _subtitleTracks.length) {
                          final originalIndex =
                              _subtitleTracks[index]['original_index'] as int?;
                          final subs = _player.state.tracks.subtitle;
                          if (originalIndex != null &&
                              originalIndex >= 0 &&
                              originalIndex < subs.length) {
                            _player.setSubtitleTrack(subs[originalIndex]);
                          }
                        }
                        setState(() => _showSubtitlePicker = false);
                        _startHideTimer();
                      },
                      onClose: () {
                        setState(() => _showSubtitlePicker = false);
                        _startHideTimer();
                      },
                    ),

                  if (_showChannelOverlay)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: ChannelOverlay(
                        currentChannel: _currentChannel,
                        onClose: () {
                          setState(() => _showChannelOverlay = false);
                          _startHideTimer();
                          _playerFocusNode.requestFocus();
                        },
                        onChannelSelected: (channel) {
                          setState(() {
                            _currentChannel = channel;
                            _title = channel.name;
                            _subtitle = channel.groupTitle;
                            _streamUrl = channel.streamUrl;
                            _contentType = 'live';
                            _showControls = true;
                          });
                          _startHideTimer();
                          ref
                              .read(lastPlayedProvider.notifier)
                              .setLastChannel(channel);
                          _player.open(Media(_streamUrl!));
                        },
                      ),
                    ),
                  if (_showVolumeOverlay)
                    VolumeOverlay(
                      rightOffset: volumeOffset,
                      initialVolume: _player.state.volume,
                      onVolumeChanged: _setVolume,
                      onClose: () {
                        setState(() => _showVolumeOverlay = false);
                        _startHideTimer();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _zapChannel(int direction) {
    if (_contentType != 'live' || _currentChannel == null) return;
    var channels = ref.read(channelProvider).filteredChannels;
    if (channels.isEmpty) {
      channels = ref.read(channelProvider).channels;
    }
    if (channels.isEmpty) return;

    final currentIndex = channels.indexWhere(
      (c) => c.streamId == _currentChannel!.streamId,
    );
    if (currentIndex == -1) return;

    final nextIndex =
        (currentIndex + direction + channels.length) % channels.length;
    final nextChan = channels[nextIndex];

    setState(() {
      _currentChannel = nextChan;
      _title = nextChan.name;
      _subtitle = nextChan.groupTitle;
      _streamUrl = nextChan.streamUrl;
      _showControls = true;
    });
    _startHideTimer();
    ref.read(lastPlayedProvider.notifier).setLastChannel(nextChan);
    _player.open(Media(_streamUrl!));
  }

  bool _isZapPrev(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.channelUp ||
      key == LogicalKeyboardKey.pageUp;

  bool _isZapNext(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.channelDown ||
      key == LogicalKeyboardKey.pageDown;

  bool _isSelect(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.gameButtonA;

  void _changeVolume(double delta) {
    var newVol = _player.state.volume + delta;
    newVol = newVol.clamp(0.0, 100.0);
    _setVolume(newVol);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.mediaStop) {
      _safeExitPlayer();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.mediaPlayPause ||
        event.logicalKey == LogicalKeyboardKey.mediaPlay ||
        event.logicalKey == LogicalKeyboardKey.mediaPause) {
      if (_contentType == 'live') {
        _refreshLiveStream();
      } else {
        _player.playOrPause();
      }
      return KeyEventResult.handled;
    }

    // REMOTE EPG / GUIDE / MENU / INFO BUTTON TOGGLES CHANNEL LIST OVERLAY OR SEASONS
    if (event.logicalKey == LogicalKeyboardKey.guide ||
        event.logicalKey == LogicalKeyboardKey.info ||
        event.logicalKey == LogicalKeyboardKey.contextMenu ||
        event.logicalKey == LogicalKeyboardKey.tvDataService) {
      if (_showChannelOverlay) {
        setState(() => _showChannelOverlay = false);
        _startHideTimer();
        return KeyEventResult.handled;
      }
      _hideTimer?.cancel();
      if (_contentType == 'series' && _currentMovieItem != null) {
        _controlsFocusScopeNode.focusedChild?.unfocus();
        setState(() {
          _showControls = false;
          _showAudioPicker = false;
          _showSubtitlePicker = false;
          _showVolumeOverlay = false;
        });
        showDialog(
          context: context,
          barrierColor: kOverlayDimBackground,
          builder: (ctx) =>
              VodDetails(item: _currentMovieItem!, isOpenedFromPlayer: true),
        ).then((result) {
          if (mounted) _playerFocusNode.requestFocus();
          if (result != null && result is Map<String, dynamic>) {
            final ep = result['episode'];
            final seasonNum = (result['seasonNumber'] as int?) ?? 1;
            final streamUrl = result['streamUrl'] as String?;
            if (ep != null && streamUrl != null && streamUrl.isNotEmpty) {
              final epNum = ep.episodeNum as int? ?? 1;
              final epTitle = (ep.title as String?) ?? '';
              setState(() {
                _streamUrl = streamUrl;
                _subtitle =
                    'S$seasonNum E$epNum${epTitle.isNotEmpty ? ' · $epTitle' : ''}';
              });
              ref
                  .read(lastPlayedProvider.notifier)
                  .setLastSeries(_currentMovieItem!, ep, seasonNum, streamUrl);
              _player.open(Media(streamUrl));
            }
          }
        });
      } else {
        setState(() {
          _showChannelOverlay = true;
          _showControls = false;
          _showAudioPicker = false;
          _showSubtitlePicker = false;
          _showVolumeOverlay = false;
        });
      }
      return KeyEventResult.handled;
    }

    // REMOTE SUBTITLE / CLOSED CAPTION BUTTON TOGGLES SUBTITLE OVERLAY
    if (event.logicalKey == LogicalKeyboardKey.closedCaptionToggle ||
        event.logicalKey == LogicalKeyboardKey.subtitle) {
      if (_subtitleTracks.length > 1) {
        setState(() {
          _showSubtitlePicker = !_showSubtitlePicker;
          _showAudioPicker = false;
          _showVolumeOverlay = false;
          if (_showSubtitlePicker) {
            _showControls = true;
            _hideTimer?.cancel();
          } else {
            _startHideTimer();
          }
        });
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      _changeVolume(10);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      _changeVolume(-10);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeMute) {
      _setVolume(_player.state.volume > 0 ? 0 : 100);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (_showChannelOverlay) {
        setState(() => _showChannelOverlay = false);
        _startHideTimer();
      } else if (_showAudioPicker) {
        setState(() => _showAudioPicker = false);
        _startHideTimer();
      } else if (_showSubtitlePicker) {
        setState(() => _showSubtitlePicker = false);
        _startHideTimer();
      } else if (_showVolumeOverlay) {
        setState(() => _showVolumeOverlay = false);
        _startHideTimer();
      } else if (_showControls) {
        _controlsFocusScopeNode.focusedChild?.unfocus();
        setState(() => _showControls = false);
        _playerFocusNode.requestFocus();
      } else {
        _safeExitPlayer();
      }
      return KeyEventResult.handled;
    }

    if (_showChannelOverlay ||
        _showAudioPicker ||
        _showSubtitlePicker ||
        _showVolumeOverlay) {
      return KeyEventResult.ignored;
    }

    if (!_showControls) {
      if (_contentType == 'live') {
        if (_isZapPrev(event.logicalKey)) {
          _zapChannel(-1);
          return KeyEventResult.handled;
        }
        if (_isZapNext(event.logicalKey)) {
          _zapChannel(1);
          return KeyEventResult.handled;
        }
        if (_isSelect(event.logicalKey)) {
          _showControlsAndResetTimer();
          return KeyEventResult.handled;
        }
      } else {
        if (_isSelect(event.logicalKey)) {
          _showControlsAndResetTimer();
          return KeyEventResult.handled;
        }
      }
    } else {
      if (_contentType == 'live') {
        if (_isZapPrev(event.logicalKey)) {
          _zapChannel(-1);
          _startHideTimer();
          return KeyEventResult.handled;
        }
        if (_isZapNext(event.logicalKey)) {
          _zapChannel(1);
          _startHideTimer();
          return KeyEventResult.handled;
        }
      }

      if (_isSelect(event.logicalKey) && !_controlsFocusScopeNode.hasFocus) {
        if (_contentType == 'live' || _contentType == 'series') {
          _listButtonFocusNode.requestFocus();
        } else {
          _playButtonFocusNode.requestFocus();
        }
        _startHideTimer();
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _startHideTimer();
      }
    }

    return KeyEventResult.ignored;
  }
}
